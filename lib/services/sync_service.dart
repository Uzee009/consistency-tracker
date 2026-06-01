import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'pocketbase_service.dart';
import 'connectivity_service.dart';
import 'database_service.dart';
import 'account_registry.dart';

enum SyncStatus { success, offline, notSignedIn, busy, error }

class SyncResult {
  final SyncStatus status;
  final int pushed;
  final int pulled;
  final String? message;
  final bool transient;

  const SyncResult(this.status, {this.pushed = 0, this.pulled = 0, this.message, this.transient = false});

  String get summary => _buildSummary();

  String _buildSummary() {
    switch (status) {
      case SyncStatus.success:
        return 'Synced ✓ (↑$pushed ↓$pulled)';
      case SyncStatus.offline:
        return 'Can\'t reach the sync server — changes will sync automatically when it\'s back.';
      case SyncStatus.notSignedIn:
        return 'You\'re not signed in. Open Settings → Sync Account to sign in.';
      case SyncStatus.busy:
        return 'Sync already in progress…';
      case SyncStatus.error:
        return message ?? 'Sync failed — will retry automatically.';
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

  Timer? _debounceTimer;
  Timer? _pollTimer;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _pendingSync = false;
  bool _autoStarted = false;
  bool _wasOnline = false;
  final List<UnsubscribeFunc> _unsubs = [];
  Future<void> _realtimeLock = Future<void>.value();
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  static const Duration _pollInterval = Duration(seconds: 60);
  static const int _retryBaseSeconds = 2;   // 2,4,8,16,32 ...
  static const int _retryCapSeconds = 60;    // capped at the poll interval

  static const int _localRetentionMs = 30 * 24 * 60 * 60 * 1000;  // 30 days
  static const int _serverRetentionMs = 90 * 24 * 60 * 60 * 1000; // 90 days
  static const int _pruneIntervalMs = 24 * 60 * 60 * 1000;         // once per day

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

      if (pushed + pulled > 0) {
        await DatabaseService.instance.recomputeAllDerived();
        dataChanged.value++;
      }

      await _maybePrune(ownerId);

      lastSyncedAt = DateTime.now();
      await AccountRegistry.instance.touch(ownerId);
      _cancelRetry();  // manual "Sync Now" success also clears pending backoff
      return SyncResult(SyncStatus.success, pushed: pushed, pulled: pulled);
    } catch (e) {
      debugPrint('Sync error: $e');
      return SyncResult(SyncStatus.error, message: _friendlyError(e), transient: _isTransient(e));
    } finally {
      isSyncing.value = false;
    }
  }

  /// Stops all sync activity. Used by main.dart's auth listener when the
  /// active account is about to change (sign-in, sign-out, or account switch),
  /// so we never sync the new account against the old account's pending writes.
  /// Awaits any in-flight `sync()` for up to 5 seconds so the caller can then
  /// safely close the DB.
  Future<void> pauseForSwitch() async {
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    _retryTimer?.cancel();
    _retryAttempt = 0;
    _pendingSync = false;

    // Wait for any in-flight sync to finish (max 5s).
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (isSyncing.value && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await _teardownRealtime();
  }

  /// Re-arms polling, realtime, and triggers a sync. Called by main.dart's
  /// auth listener AFTER a successful sign-IN and AFTER `DatabaseService.switchTo`
  /// has opened the new account's DB. Not called on sign-OUT.
  void resumeAfterSwitch() {
    if (!_autoStarted) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => requestSync(debounce: Duration.zero));
    _restartRealtime();
    requestSync();
  }

  /// Maps a sync exception to a concise, user-facing message.
  /// Raw detail is logged separately via debugPrint.
  String _friendlyError(Object e) {
    if (e is ClientException) {
      final code = e.statusCode;
      final serverMsg = e.response['message']?.toString() ?? '';
      if (code == 401 || code == 403) {
        return 'Your sync session has expired. Open Settings → Sync Account and sign in again.';
      }
      if (code == 404 || serverMsg.contains('Missing collection context')) {
        return 'The sync server isn\'t fully set up yet. Your data is safe on this device and will sync once the server is ready.';
      }
      if (code == 0) {
        return 'Can\'t reach the sync server right now — will retry automatically.';
      }
      if (code >= 500 || code == 429) {
        return 'The sync server had a hiccup — will retry automatically.';
      }
      return 'Sync was rejected by the server. Your data is safe on this device.';
    }
    return 'Can\'t reach the sync server right now — will retry automatically.';
  }

  /// Transient = worth retrying with backoff (network down, server hiccup).
  /// Permanent = don't auto-retry (bad creds / validation); wait for next natural trigger.
  bool _isTransient(Object e) {
    if (e is ClientException) {
      final code = e.statusCode;
      if (code == 0) return true;        // no HTTP response = network/connection error
      if (code >= 500) return true;      // server error
      if (code == 429) return true;      // rate limited
      return false;                      // other 4xx (400 validation, 401/403 auth, 404) = permanent
    }
    return true;                         // SocketException/TimeoutException/etc = transient
  }

  Future<void> _maybePrune(String ownerId) async {
    final lastPrune = await DatabaseService.instance.getLastPruneAt();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lastPrune != null && (now - lastPrune) < _pruneIntervalMs) return;

    try {
      // Local prune
      await DatabaseService.instance.pruneLocalTombstones(_localRetentionMs);

      // Server prune
      final client = PocketBaseService.instance.client;
      final serverCutoff = now - _serverRetentionMs;

      for (final cfg in _configs) {
        final filter =
            'owner = "${_esc(ownerId)}" && deleted = true && updated_at < $serverCutoff';
        final stale = await client
            .collection(cfg.name)
            .getFullList(batch: 200, filter: filter);

        for (final rec in stale) {
          try {
            await client.collection(cfg.name).delete(rec.id);
          } on ClientException catch (e) {
            if (e.statusCode != 404) rethrow;
          }
        }
      }

      // On success, update the last-prune timestamp
      await DatabaseService.instance.setLastPruneAt(now);
    } catch (e) {
      debugPrint('Tombstone prune skipped: $e');
    }
  }

  void requestSync({Duration debounce = _debounceDuration}) {
    _debounceTimer?.cancel();
    if (debounce == Duration.zero) {
      _runScheduled();
    } else {
      _debounceTimer = Timer(debounce, _runScheduled);
    }
  }

  Future<void> _runScheduled() async {
    if (isSyncing.value) {
      _pendingSync = true;
      return;
    }
    final result = await sync();
    switch (result.status) {
      case SyncStatus.success:
      case SyncStatus.notSignedIn:
        _cancelRetry();              // healthy or nothing-to-do: stop backoff
        break;
      case SyncStatus.offline:
        _cancelRetry();              // reconnect listener will re-trigger sync; don't hammer offline
        break;
      case SyncStatus.busy:
        break;                       // another sync running; leave any retry as-is
      case SyncStatus.error:
        if (result.transient) {
          _scheduleRetry();          // network/5xx/429: retry with backoff
        } else {
          _cancelRetry();            // permanent (auth/validation): don't auto-retry
        }
        break;
    }
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    // 2,4,8,16,32,60(cap)... using current attempt, then advance
    final secs = (_retryBaseSeconds * (1 << _retryAttempt)).clamp(_retryBaseSeconds, _retryCapSeconds);
    if (_retryAttempt < 16) _retryAttempt++; // avoid shift overflow; capped delay anyway
    _retryTimer = Timer(Duration(seconds: secs), () => _runScheduled());
  }

  void _onSyncingChange() {
    if (!isSyncing.value && _pendingSync) {
      _pendingSync = false;
      requestSync(debounce: Duration.zero);
    }
  }

  void _onLocalChange() => requestSync();

  void _onConnectivityChange() {
    final online = ConnectivityService.instance.isOnline.value;
    if (online && !_wasOnline) {
      _restartRealtime();
      requestSync();
    }
    _wasOnline = online;
  }

  void _onAuthOrClientChange() {
    // Intentionally a no-op. main.dart's auth listener is the single
    // switch chokepoint (it calls pauseForSwitch / DatabaseService.switchTo /
    // resumeAfterSwitch). Listener kept attached to preserve startAuto/stopAuto symmetry.
  }

  void _restartRealtime() {
    _realtimeLock = _realtimeLock.then((_) async {
      await _teardownRealtime();
      await _setupRealtime();
    });
  }

  Future<void> _setupRealtime() async {
    if (!PocketBaseService.instance.isAuthenticated) return;
    final client = PocketBaseService.instance.client;
    for (final cfg in _configs) {
      try {
        final unsub = await client.collection(cfg.name).subscribe('*', (e) {
          requestSync();
        });
        _unsubs.add(unsub);
      } catch (e) {
        debugPrint('Realtime subscribe failed for ${cfg.name}: $e');
      }
    }
  }

  Future<void> _teardownRealtime() async {
    final subs = List<UnsubscribeFunc>.from(_unsubs);
    _unsubs.clear();
    for (final unsub in subs) {
      try {
        await unsub();
      } catch (_) {}
    }
  }

  void startAuto() {
    if (_autoStarted) return;
    _autoStarted = true;
    _wasOnline = ConnectivityService.instance.isOnline.value;

    DatabaseService.instance.localChanges.addListener(_onLocalChange);
    ConnectivityService.instance.isOnline.addListener(_onConnectivityChange);
    PocketBaseService.instance.authState.addListener(_onAuthOrClientChange);
    PocketBaseService.instance.clientRevision.addListener(_onAuthOrClientChange);
    isSyncing.addListener(_onSyncingChange);

    _pollTimer = Timer.periodic(_pollInterval, (_) => requestSync(debounce: Duration.zero));

    _restartRealtime();
    requestSync();
  }

  void stopAuto() {
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    _retryTimer?.cancel();
    _retryAttempt = 0;
    DatabaseService.instance.localChanges.removeListener(_onLocalChange);
    ConnectivityService.instance.isOnline.removeListener(_onConnectivityChange);
    PocketBaseService.instance.authState.removeListener(_onAuthOrClientChange);
    PocketBaseService.instance.clientRevision.removeListener(_onAuthOrClientChange);
    isSyncing.removeListener(_onSyncingChange);
    _teardownRealtime();
    _autoStarted = false;
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
