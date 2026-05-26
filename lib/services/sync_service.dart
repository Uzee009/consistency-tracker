import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'pocketbase_service.dart';
import 'connectivity_service.dart';
import 'database_service.dart';

enum SyncStatus { success, offline, notSignedIn, busy, error }

class SyncResult {
  final SyncStatus status;
  final int pushed;
  final int pulled;
  final String? message;

  const SyncResult(this.status, {this.pushed = 0, this.pulled = 0, this.message});

  String get summary => _buildSummary();

  String _buildSummary() {
    switch (status) {
      case SyncStatus.success:
        return 'Synced: ↑$pushed ↓$pulled';
      case SyncStatus.offline:
        return 'Offline — nothing to sync';
      case SyncStatus.notSignedIn:
        return 'Not signed in';
      case SyncStatus.busy:
        return 'Sync already in progress';
      case SyncStatus.error:
        return 'Sync failed: $message';
    }
  }
}

class _Col {
  final String name;
  final List<String> pk; // natural-key columns
  final List<String> textCols; // text fields
  final List<String> intCols; // number fields
  final List<String> boolCols; // bool fields (stored as 0/1)

  const _Col({
    required this.name,
    required this.pk,
    required this.textCols,
    required this.intCols,
    required this.boolCols,
  });
}

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final ValueNotifier<bool> isSyncing = ValueNotifier(false);
  /// Bumped after every successful sync so the UI can reload from the DB.
  final ValueNotifier<int> dataChanged = ValueNotifier(0);
  DateTime? lastSyncedAt;

  final List<_Col> _configs = [
    const _Col(
      name: 'tasks',
      pk: ['sid'],
      textCols: ['sid', 'name', 'type', 'created_at', 'frequency_type'],
      intCols: ['duration_days', 'weekly_target', 'updated_at'],
      boolCols: ['is_perpetual', 'is_active', 'deleted', 'dirty'],
    ),
    const _Col(
      name: 'task_status',
      pk: ['date', 'task_sid'],
      textCols: ['date', 'task_sid', 'status'],
      intCols: ['updated_at'],
      boolCols: ['deleted', 'dirty'],
    ),
    const _Col(
      name: 'day_meta',
      pk: ['date'],
      textCols: ['date'],
      intCols: ['pomodoro_sessions', 'pomodoro_goal', 'updated_at'],
      boolCols: ['cheat_used', 'deleted', 'dirty'],
    ),
  ];

  Future<SyncResult> sync() async {
    if (isSyncing.value) return const SyncResult(SyncStatus.busy);
    if (!PocketBaseService.instance.isAuthenticated) {
      return const SyncResult(SyncStatus.notSignedIn);
    }

    isSyncing.value = true;
    try {
      final online = await ConnectivityService.instance.checkNow();
      if (!online) return const SyncResult(SyncStatus.offline);

      final ownerId = PocketBaseService.instance.client.authStore.record?.id;
      if (ownerId == null || ownerId.isEmpty) {
        return const SyncResult(SyncStatus.notSignedIn);
      }

      int pushed = 0;
      int pulled = 0;

      for (final cfg in _configs) {
        pushed += await _push(cfg, ownerId);
        pulled += await _pull(cfg, ownerId);
      }

      await DatabaseService.instance.recomputeAllDerived();
      lastSyncedAt = DateTime.now();
      dataChanged.value++;

      return SyncResult(SyncStatus.success, pushed: pushed, pulled: pulled);
    } catch (e) {
      return SyncResult(SyncStatus.error, message: e.toString());
    } finally {
      isSyncing.value = false;
    }
  }

  Future<int> _push(_Col cfg, String ownerId) async {
    final db = await DatabaseService.instance.database;
    final client = PocketBaseService.instance.client;
    final rows = await db.query(cfg.name, where: 'dirty = 1');
    int count = 0;

    for (final row in rows) {
      final Map<String, dynamic> body = {};

      for (final col in cfg.textCols) {
        body[col] = row[col] as String?;
      }
      for (final col in cfg.intCols) {
        body[col] = (row[col] as num?)?.toInt();
      }
      for (final col in cfg.boolCols) {
        if (col != 'dirty') {
          body[col] = (row[col] as int? ?? 0) == 1;
        }
      }

      // Force 'dirty' to always be false in body (server rows never dirty)
      body['dirty'] = false;
      body['owner'] = ownerId;

      // Build lookup filter
      String filter = 'owner = "${_esc(ownerId)}"';
      for (final pkCol in cfg.pk) {
        final val = row[pkCol];
        filter += ' && $pkCol = "${_esc(val)}"';
      }

      RecordModel? existing;
      try {
        existing = await client.collection(cfg.name).getFirstListItem(filter);
      } catch (e) {
        if (e is ClientException && e.statusCode == 404) {
          existing = null;
        } else {
          rethrow;
        }
      }

      if (existing == null) {
        await client.collection(cfg.name).create(body: body);
        count++;
      } else {
        // LWW (Last Write Wins)
        final localUpd = (row['updated_at'] as num).toInt();
        final serverUpd = existing.getIntValue('updated_at');
        if (localUpd > serverUpd) {
          await client.collection(cfg.name).update(existing.id, body: body);
          count++;
        }
      }

      // Clear local dirty
      final Map<String, dynamic> updateData = {'dirty': 0};
      String where = cfg.pk.map((c) => '$c = ?').join(' AND ');
      List<dynamic> whereArgs = cfg.pk.map((c) => row[c]).toList();

      await db.update(cfg.name, updateData, where: where, whereArgs: whereArgs);
    }

    return count;
  }

  Future<int> _pull(_Col cfg, String ownerId) async {
    final db = await DatabaseService.instance.database;
    final client = PocketBaseService.instance.client;

    String? cursor = await DatabaseService.instance.getSyncCursor(cfg.name);
    String? maxUpdated = cursor;
    int count = 0;
    int page = 1;

    while (true) {
      String filter = 'owner = "${_esc(ownerId)}"';
      if (cursor != null && cursor.isNotEmpty) {
        filter += ' && updated >= "${_esc(cursor)}"';
      }

      final res = await client.collection(cfg.name).getList(
            page: page,
            perPage: 200,
            filter: filter,
            sort: '+updated',
          );

      for (final rec in res.items) {
        if (await _applyRemote(cfg, db, rec)) {
          count++;
        }
        final recUpdated = rec.getStringValue('updated');
        if (maxUpdated == null || recUpdated.compareTo(maxUpdated) > 0) {
          maxUpdated = recUpdated;
        }
      }

      if (page >= res.totalPages || res.items.isEmpty) {
        break;
      }
      page++;
    }

    if (maxUpdated != null && maxUpdated.isNotEmpty) {
      await DatabaseService.instance.setSyncCursor(cfg.name, maxUpdated);
    }

    return count;
  }

  Future<bool> _applyRemote(_Col cfg, Database db, RecordModel rec) async {
    // Build local pk where + args
    final String where = cfg.pk.map((c) => '$c = ?').join(' AND ');
    final List<dynamic> whereArgs = cfg.pk.map((c) => rec.getStringValue(c)).toList();

    final local = await db.query(cfg.name, where: where, whereArgs: whereArgs);

    final Map<String, dynamic> localMap = {};
    for (final col in cfg.textCols) {
      localMap[col] = rec.getStringValue(col);
    }
    for (final col in cfg.intCols) {
      localMap[col] = rec.getIntValue(col);
    }
    for (final col in cfg.boolCols) {
      localMap[col] = rec.getBoolValue(col) ? 1 : 0;
    }
    localMap['dirty'] = 0;

    final remoteUpd = rec.getIntValue('updated_at');

    if (local.isEmpty) {
      await db.insert(cfg.name, localMap, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    } else {
      final localUpd = (local.first['updated_at'] as num).toInt();
      if (remoteUpd > localUpd) {
        await db.update(cfg.name, localMap, where: where, whereArgs: whereArgs);
        return true;
      }
    }

    return false;
  }

  String _esc(Object? v) => (v?.toString() ?? '').replaceAll('"', r'\"');
}
