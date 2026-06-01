import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../services/scoring_service.dart';
import 'account_registry.dart';

class DatabaseService {
  static const String dbName = String.fromEnvironment(
    'DATABASE_NAME',
    defaultValue: 'consistency_tracker.db'
  );

  static String prefixedKey(String key) => '$dbName:$key';

  static Database? _database;
  static String? _activeUserId;
  static const String _localId = '_local';

  /// Directory under documentsDir that holds per-account DB files.
  /// `accounts/` in prod, `accounts_dev/` when a non-default DATABASE_NAME is set
  /// (dev override is directory-scoped per Step 15B Design Decision #2).
  static String get _accountsDir =>
      dbName == 'consistency_tracker.db' ? 'accounts' : 'accounts_dev';

  static final DatabaseService instance = DatabaseService._constructor();

  /// Serializes derived-cache writers (createOrUpdateDayRecord vs recomputeAllDerived)
  /// to prevent read-then-write skew.
  static final Lock _writeLock = Lock();

  static const String lastPruneKey = '__last_prune__';

  /// Bumped after every local write that sets dirty=1, so the sync coordinator
  /// can schedule a debounced push.
  final ValueNotifier<int> localChanges = ValueNotifier<int>(0);

  /// Bumped whenever switchTo() successfully opens a new DB.
  /// Listeners use this to know when to re-fetch data from the active DB.
  final ValueNotifier<int> activeDbRevision = ValueNotifier<int>(0);

  void _notifyLocalChange() {
    localChanges.value++;
  }

  final String usersTable = 'users';
  final String tasksTable = 'tasks';
  final String taskStatusTable = 'task_status';
  final String dayMetaTable = 'day_meta';
  final String dayRecordsTable = 'day_records'; // Local derived cache
  final String monthlyUsageTable = 'monthly_usage';
  final String syncStateTable = 'sync_state';

  DatabaseService._constructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Resolves the absolute path to the SQLite file for the given account.
  /// `userId == null` (or empty) maps to the anonymous `_local.db` workspace
  /// (Model E: only exists pre-first-signin).
  Future<String> _dbPathFor(String? userId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(join(docs.path, _accountsDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final id = (userId == null || userId.isEmpty) ? _localId : userId;
    return join(dir.path, '$id.db');
  }

  Future<Database> _initDatabase() async {
    String path = await _dbPathFor(_activeUserId);
    return await openDatabase(
      path,
      version: 9,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode=WAL;');
        await db.execute('PRAGMA busy_timeout=5000;');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Closes the open SQLite handle so a different account's DB can be opened.
  /// Safe to call multiple times.
  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) {
      try {
        await db.close();
      } catch (_) {
        // best-effort: ignore close errors so a sticky handle never blocks a switch
      }
    }
  }

  /// Switches the active account's DB file. Closes the current handle,
  /// updates internal active-user state, and stamps the access-time registry.
  /// The new DB opens lazily on the next `database` getter access.
  ///
  /// Pure data-layer operation: callers (main.dart auth listener) are
  /// responsible for pausing/resuming SyncService around this call.
  Future<void> switchTo(String? userId) async {
    final normalized = (userId == null || userId.isEmpty) ? null : userId;
    if (_activeUserId == normalized && _database != null) {
      // already active and open — just touch and return
      await AccountRegistry.instance.touch(normalized);
      return;
    }
    await close();
    _activeUserId = normalized;
    await AccountRegistry.instance.touch(normalized);

    // Fire the revision notifier so listeners (MyApp, HomeScreen) know to refresh.
    activeDbRevision.value++;
  }

  Future<void> migrateLegacyDb({required String? activeUserId}) async {
    final docs = await getApplicationDocumentsDirectory();
    final legacy = File(join(docs.path, dbName));
    if (!await legacy.exists()) return;
    final targetPath = await _dbPathFor(activeUserId);
    final target = File(targetPath);
    if (await target.exists()) {
      debugPrint('DatabaseService: legacy DB present but per-account DB already exists at $targetPath — skipping migration');
      return;
    }
    try {
      await legacy.rename(targetPath);

      // Best-effort: move WAL sidecars too so they don't orphan in the documents root.
      for (final suffix in ['-wal', '-shm']) {
        final side = File('${legacy.path}$suffix');
        if (await side.exists()) {
          try {
            await side.rename('$targetPath$suffix');
          } catch (e) {
            debugPrint('DatabaseService: failed to move legacy sidecar $suffix: $e');
          }
        }
      }

      debugPrint('DatabaseService: migrated legacy DB to $targetPath');
    } catch (e) {
      debugPrint('DatabaseService: legacy DB migration FAILED: $e');
      rethrow;
    }
  }

  /// Deletes the on-disk SQLite files for the given user ids (per-account dir).
  /// Best-effort: missing files and individual failures are logged, not thrown.
  /// Used after AccountRegistry.evictIdle() returns the dormant ids.
  Future<void> deleteAccountDbs(List<String> userIds) async {
    if (userIds.isEmpty) return;
    for (final id in userIds) {
      try {
        final path = await _dbPathFor(id);
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
          debugPrint('DatabaseService: evicted DB $path');
        }
        // Also clean up sqflite sidecars if present.
        for (final suffix in ['-wal', '-shm', '-journal']) {
          final side = File('$path$suffix');
          if (await side.exists()) {
            try { await side.delete(); } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('DatabaseService: failed to evict DB for $id: $e');
      }
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $usersTable (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        monthly_cheat_days INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tasksTable (
        sid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        duration_days INTEGER NOT NULL,
        is_perpetual INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL,
        frequency_type TEXT DEFAULT 'daily',
        weekly_target INTEGER DEFAULT 1,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE $taskStatusTable (
        date TEXT NOT NULL,
        task_sid TEXT NOT NULL,
        status TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        dirty INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(date, task_sid)
      )
    ''');
    await db.execute('''
      CREATE TABLE $dayMetaTable (
        date TEXT PRIMARY KEY,
        cheat_used INTEGER NOT NULL DEFAULT 0,
        pomodoro_sessions INTEGER NOT NULL DEFAULT 0,
        pomodoro_goal INTEGER NOT NULL DEFAULT 4,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE $dayRecordsTable (
        date TEXT PRIMARY KEY,
        completed_task_ids TEXT NOT NULL,
        skipped_task_ids TEXT NOT NULL,
        cheat_used INTEGER NOT NULL,
        completion_score REAL NOT NULL,
        visual_state TEXT NOT NULL,
        pomodoro_sessions INTEGER DEFAULT 0,
        pomodoro_goal INTEGER DEFAULT 4
      )
    ''');
    await db.execute('''
      CREATE TABLE $monthlyUsageTable (
        year_month TEXT PRIMARY KEY,
        cheat_days_used INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $syncStateTable (
        collection TEXT PRIMARY KEY,
        cursor TEXT NOT NULL
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE $dayRecordsTable ADD COLUMN skipped_task_ids TEXT DEFAULT ''");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE $tasksTable ADD COLUMN is_perpetual INTEGER DEFAULT 0");
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE $usersTable ADD COLUMN monthly_cheat_days INTEGER DEFAULT 2");
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE $monthlyUsageTable (
          year_month TEXT PRIMARY KEY,
          cheat_days_used INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE $dayRecordsTable ADD COLUMN pomodoro_sessions INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE $dayRecordsTable ADD COLUMN pomodoro_goal INTEGER DEFAULT 4");
    }
    if (oldVersion < 7) {
      await db.execute("ALTER TABLE $tasksTable ADD COLUMN frequency_type TEXT DEFAULT 'daily'");
      await db.execute("ALTER TABLE $tasksTable ADD COLUMN weekly_target INTEGER DEFAULT 1");
    }
    if (oldVersion < 8) {
      // PHASE 0: Migrate to sid identity + task_status/day_meta.
      // NOTE: sqflite runs onUpgrade INSIDE an exclusive transaction
      // (sqflite_common database_mixin.dart). Any exception thrown here rolls
      // the entire migration back, so this block is already atomic/crash-safe.
      // Do NOT wrap it in a nested db.transaction() — that only reuses this same
      // open transaction and adds no extra safety.
      const uuid = Uuid();
      final now = DateTime.now().millisecondsSinceEpoch;

      // --- Step 1: Rebuild tasks table with sid PK, backfill UUIDs ---
      final oldTasks = await db.query(tasksTable);
      final Map<int, String> oldIntIdToSid = {};

      await db.execute("DROP TABLE IF EXISTS tasks_new");
      await db.execute('''
        CREATE TABLE tasks_new (
          sid TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          duration_days INTEGER NOT NULL,
          is_perpetual INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          is_active INTEGER NOT NULL,
          frequency_type TEXT DEFAULT 'daily',
          weekly_target INTEGER DEFAULT 1,
          updated_at INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL DEFAULT 0,
          dirty INTEGER NOT NULL DEFAULT 0
        )
      ''');

      for (var row in oldTasks) {
        final newSid = uuid.v4();
        oldIntIdToSid[(row['id'] as num).toInt()] = newSid;
        await db.execute('''
          INSERT INTO tasks_new
          (sid, name, type, duration_days, is_perpetual, created_at, is_active, frequency_type, weekly_target, updated_at, deleted, dirty)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0)
        ''', [
          newSid,
          row['name'],
          row['type'],
          row['duration_days'],
          row['is_perpetual'],
          row['created_at'],
          row['is_active'],
          row['frequency_type'] ?? 'daily',
          row['weekly_target'] ?? 1,
          now,
        ]);
      }

      await db.execute("DROP TABLE $tasksTable");
      await db.execute("ALTER TABLE tasks_new RENAME TO $tasksTable");

      // --- Step 2: Create task_status and day_meta tables ---
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $taskStatusTable (
          date TEXT NOT NULL,
          task_sid TEXT NOT NULL,
          status TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted INTEGER NOT NULL DEFAULT 0,
          dirty INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY(date, task_sid)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $dayMetaTable (
          date TEXT PRIMARY KEY,
          cheat_used INTEGER NOT NULL DEFAULT 0,
          pomodoro_sessions INTEGER NOT NULL DEFAULT 0,
          pomodoro_goal INTEGER NOT NULL DEFAULT 4,
          updated_at INTEGER NOT NULL,
          deleted INTEGER NOT NULL DEFAULT 0,
          dirty INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // --- Step 3: Migrate day_records into task_status + day_meta and
      // recompute the derived completion_score / visual_state cache. ---
      // Load freshly-migrated tasks so scores can be re-derived.
      // Match the live getActiveTasksForDate scoring path: only non-deleted,
      // active tasks count toward a day's derived score.
      final migratedTaskMaps =
          await db.query(tasksTable, where: 'deleted = 0 AND is_active = 1');
      final migratedTasks =
          migratedTaskMaps.map((m) => Task.fromMap(m)).toList();

      // Process days chronologically so weekly-task scoring sees correct history.
      final oldRecords = await db.query(dayRecordsTable, orderBy: 'date ASC');
      final List<DayRecord> history = [];

      for (var rec in oldRecords) {
        final dateStr = rec['date'] as String;

        // Parse legacy int CSVs -> sids (dropping ids whose task was
        // hard-deleted before v8; those task rows no longer exist).
        final newCompletedSids =
            _remapCsvToSids(rec['completed_task_ids'] as String?, oldIntIdToSid);
        final newSkippedSids =
            _remapCsvToSids(rec['skipped_task_ids'] as String?, oldIntIdToSid);
        // A sid cannot be both completed and skipped; completed wins.
        newSkippedSids.removeWhere(newCompletedSids.contains);

        for (var sid in newCompletedSids) {
          await db.execute('''
            INSERT OR REPLACE INTO $taskStatusTable
            (date, task_sid, status, updated_at, deleted, dirty)
            VALUES (?, ?, 'completed', ?, 0, 0)
          ''', [dateStr, sid, now]);
        }
        for (var sid in newSkippedSids) {
          await db.execute('''
            INSERT OR REPLACE INTO $taskStatusTable
            (date, task_sid, status, updated_at, deleted, dirty)
            VALUES (?, ?, 'skipped', ?, 0, 0)
          ''', [dateStr, sid, now]);
        }

        final cheatUsed = ((rec['cheat_used'] as int?) ?? 0) == 1;
        await db.execute('''
          INSERT OR REPLACE INTO $dayMetaTable
          (date, cheat_used, pomodoro_sessions, pomodoro_goal, updated_at, deleted, dirty)
          VALUES (?, ?, ?, ?, ?, 0, 0)
        ''', [
          dateStr,
          cheatUsed ? 1 : 0,
          rec['pomodoro_sessions'] ?? 0,
          rec['pomodoro_goal'] ?? 4,
          now,
        ]);

        // Recompute derived score + visual_state from migrated sids so the
        // day_records cache stays consistent after orphaned ids are dropped.
        final tempRecord = DayRecord(
          date: dateStr,
          completedTaskIds: newCompletedSids,
          skippedTaskIds: newSkippedSids,
          cheatUsed: cheatUsed,
          pomodoroSessionsCompleted: (rec['pomodoro_sessions'] as int?) ?? 0,
          pomodoroGoal: (rec['pomodoro_goal'] as int?) ?? 4,
        );
        final activeTasks =
            _activeTasksFor(DateTime.parse(dateStr), migratedTasks);
        final scoreResult = ScoringService.calculateDayScore(
          allTasks: activeTasks,
          dayRecord: tempRecord,
          history: history,
        );
        final finalRecord = tempRecord.copyWith(
          completionScore: scoreResult.completionScore,
          visualState: scoreResult.visualState,
        );

        await db.update(
          dayRecordsTable,
          finalRecord.toMap(),
          where: 'date = ?',
          whereArgs: [dateStr],
        );
        history.add(finalRecord);
      }
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $syncStateTable (
          collection TEXT PRIMARY KEY,
          cursor TEXT NOT NULL
        )
      ''');
    }
  }

  // Parse a legacy comma-joined int-id CSV into sids, dropping any id that no
  // longer maps to an existing task (e.g. tasks hard-deleted before v8).
  List<String> _remapCsvToSids(String? csv, Map<int, String> idToSid) {
    final result = <String>[];
    if (csv == null || csv.isEmpty) return result;
    for (final part in csv.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final intId = int.tryParse(trimmed);
      if (intId != null && idToSid.containsKey(intId)) {
        result.add(idToSid[intId]!);
      }
    }
    return result;
  }

  // In-memory equivalent of getActiveTasksForDate's date-window filter, used
  // during migration to re-derive day scores.
  List<Task> _activeTasksFor(DateTime date, List<Task> tasks) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return tasks.where((task) {
      final created = DateTime(
          task.createdAt.year, task.createdAt.month, task.createdAt.day);
      if (targetDate.isBefore(created)) return false;
      if (task.type == TaskType.temporary) {
        return targetDate.isAtSameMomentAs(created);
      } else if (task.type == TaskType.daily) {
        if (task.isPerpetual) return true;
        final expiration = created.add(Duration(days: task.durationDays));
        return targetDate.isBefore(expiration);
      }
      return false;
    }).toList();
  }

  // --- Sync cursor (per-device, stored in this DB so two instances on one
  // machine don't share cursors via shared_preferences). ---
  Future<String?> getSyncCursor(String collection) async {
    final db = await database;
    final rows = await db.query(
      syncStateTable,
      columns: ['cursor'],
      where: 'collection = ?',
      whereArgs: [collection],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['cursor'] as String?;
  }

  Future<void> setSyncCursor(String collection, String cursor) async {
    final db = await database;
    await db.insert(
      syncStateTable,
      {'collection': collection, 'cursor': cursor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Clears the per-collection pull cursors so the next sync performs a full pull.
  /// Called when the sync server URL changes — a cursor from one server's timeline
  /// must not be reused against a different server. Leaves the prune marker intact.
  Future<void> clearSyncCursors() async {
    final db = await database;
    await db.delete(
      syncStateTable,
      where: 'collection IN (?, ?, ?)',
      whereArgs: [tasksTable, taskStatusTable, dayMetaTable],
    );
  }

  /// Hard-deletes local tombstones (deleted=1) that are already pushed (dirty=0)
  /// and older than [retentionMs]. The server retains the canonical tombstone longer,
  /// so a later re-pull harmlessly re-inserts it as deleted=1. Returns rows deleted.
  Future<int> pruneLocalTombstones(int retentionMs) async {
    final db = await database;
    final cutoff = DateTime.now().millisecondsSinceEpoch - retentionMs;
    int total = 0;

    final tables = [tasksTable, taskStatusTable, dayMetaTable];
    for (final table in tables) {
      total += await db.delete(
        table,
        where: 'deleted = 1 AND dirty = 0 AND updated_at < ?',
        whereArgs: [cutoff],
      );
    }
    return total;
  }

  Future<int?> getLastPruneAt() async {
    final v = await getSyncCursor(lastPruneKey);
    return v == null || v.isEmpty ? null : int.tryParse(v);
  }

  Future<void> setLastPruneAt(int epochMs) async {
    await setSyncCursor(lastPruneKey, epochMs.toString());
  }

  /// Recomputes the entire day_records cache from raw task_status and day_meta tables.
  /// Used after a sync to ensure the dashboard reflects the newly-merged reality.
  /// FIX 1: Entire method body is wrapped in a single transaction to ensure atomicity.
  Future<void> recomputeAllDerived() async {
    await _writeLock.synchronized(() async {
      final db = await database;

      await db.transaction((txn) async {
        // Clear the entire day_records cache to ensure no phantom rows persist
        await txn.delete(dayRecordsTable);

        // 1. Load active tasks (non-deleted, is_active=1)
        final taskMaps =
            await txn.query(tasksTable, where: 'deleted = 0 AND is_active = 1');
        final tasks = taskMaps.map((m) => Task.fromMap(m)).toList();

        // 2. Collect DISTINCT dates from task_status and day_meta where deleted=0
        final statusDates = await txn
            .rawQuery('SELECT DISTINCT date FROM $taskStatusTable WHERE deleted = 0');
        final metaDates = await txn
            .rawQuery('SELECT DISTINCT date FROM $dayMetaTable WHERE deleted = 0');

        final allDates = <String>{};
        for (var r in statusDates) {
          allDates.add(r['date'] as String);
        }
        for (var r in metaDates) {
          allDates.add(r['date'] as String);
        }

        // 3. Sort ascending
        final sortedDates = allDates.toList()..sort();

        final List<DayRecord> history = [];

        // 4. For each date chronologically:
        for (final dateStr in sortedDates) {
          // Load completed/skipped sids from task_status where deleted=0
          final statusMaps = await txn.query(taskStatusTable,
              where: 'date = ? AND deleted = 0', whereArgs: [dateStr]);
          final completedSids = statusMaps
              .where((m) => m['status'] == 'completed')
              .map((m) => m['task_sid'] as String)
              .toList();
          final skippedSids = statusMaps
              .where((m) => m['status'] == 'skipped')
              .map((m) => m['task_sid'] as String)
              .toList();

          // Load day_meta row
          final metaMaps = await txn.query(dayMetaTable,
              where: 'date = ? AND deleted = 0', whereArgs: [dateStr]);
          final meta = metaMaps.isNotEmpty ? metaMaps.first : null;

          // Compute tempRecord
          final tempRecord = DayRecord(
            date: dateStr,
            completedTaskIds: completedSids,
            skippedTaskIds: skippedSids,
            cheatUsed: meta != null ? (meta['cheat_used'] == 1) : false,
            pomodoroSessionsCompleted:
                meta != null ? (meta['pomodoro_sessions'] as int? ?? 0) : 0,
            pomodoroGoal: meta != null ? (meta['pomodoro_goal'] as int? ?? 4) : 4,
          );

          // Get activeTasks = _activeTasksFor(date, tasks)
          final activeTasks = _activeTasksFor(DateTime.parse(dateStr), tasks);

          // Compute scoreResult = ScoringService.calculateDayScore(allTasks: activeTasks, dayRecord: tempRecord, history: history)
          final scoreResult = ScoringService.calculateDayScore(
            allTasks: activeTasks,
            dayRecord: tempRecord,
            history: history,
          );

          // Insert into day_records with final scores
          final finalRecord = tempRecord.copyWith(
            completionScore: scoreResult.completionScore,
            visualState: scoreResult.visualState,
          );

          await txn.insert(
            dayRecordsTable,
            finalRecord.toMap(),
          );

          // Add to history list
          history.add(finalRecord);
        }
      });
    });
  }

  // --- User Management ---
  Future<int> createUser(User user) async {
    Database db = await instance.database;
    return await db.insert(usersTable, user.toMap());
  }

  Future<int> updateUser(User user) async {
    Database db = await instance.database;
    return await db.update(
      usersTable,
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<User?> getUser(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      usersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<bool> hasUser() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(usersTable, limit: 1);
    return maps.isNotEmpty;
  }

  Future<List<User>> getAllUsers() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(usersTable);
    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  // --- Task Management ---
  Future<int> addTask(Task task) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final taskMap = task.toMap();
    taskMap['updated_at'] = now;
    taskMap['dirty'] = 1;
    final result = await db.insert(tasksTable, taskMap);
    _notifyLocalChange();
    return result;
  }

  Future<int> updateTask(Task task) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final taskMap = task.toMap();
    taskMap['updated_at'] = now;
    taskMap['dirty'] = 1;
    final result = await db.update(
      tasksTable,
      taskMap,
      where: 'sid = ?',
      whereArgs: [task.sid],
    );
    _notifyLocalChange();
    return result;
  }

  Future<int> archiveTask(String sid) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await db.update(
      tasksTable,
      {'is_active': 0, 'updated_at': now, 'dirty': 1},
      where: 'sid = ?',
      whereArgs: [sid],
    );
    _notifyLocalChange();
    return result;
  }

  Future<int> unarchiveTask(String sid) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await db.update(
      tasksTable,
      {'is_active': 1, 'updated_at': now, 'dirty': 1},
      where: 'sid = ?',
      whereArgs: [sid],
    );
    _notifyLocalChange();
    return result;
  }

  Future<int> deleteTaskPermanently(String sid) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Tombstone: never hard-delete
    await db.update(
      tasksTable,
      {'deleted': 1, 'updated_at': now, 'dirty': 1},
      where: 'sid = ?',
      whereArgs: [sid],
    );
    // Also tombstone task_status rows for this task
    await db.update(
      taskStatusTable,
      {'deleted': 1, 'updated_at': now, 'dirty': 1},
      where: 'task_sid = ?',
      whereArgs: [sid],
    );

    // Find and clean ALL day_records rows containing this sid
    final allDayRecords = await db.query(
      dayRecordsTable,
      // No WHERE clause — load all rows
    );

    for (final record in allDayRecords) {
      final completedIds = (record['completed_task_ids'] as String?) ?? '';
      final skippedIds = (record['skipped_task_ids'] as String?) ?? '';

      final newCompleted = _removeFromCompletedIds(completedIds, sid);
      final newSkipped = _removeFromCompletedIds(skippedIds, sid);

      // Only update if something changed
      if (newCompleted != completedIds || newSkipped != skippedIds) {
        await db.update(
          dayRecordsTable,
          {
            'completed_task_ids': newCompleted,
            'skipped_task_ids': newSkipped,
          },
          where: 'date = ?',
          whereArgs: [record['date']],
        );
      }
    }

    _notifyLocalChange();
    return 1;
  }

  String _removeFromCompletedIds(String? csv, String sid) {
    if (csv == null || csv.isEmpty) return '';
    return csv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s != sid)
        .join(',');
  }

  Future<List<Task>> getActiveTasksForDate(DateTime date, {bool includeArchived = false}) async {
    Database db = await instance.database;

    String whereClause = 'deleted = 0 AND is_active = ?';
    List<dynamic> whereArgs = [1];

    if (includeArchived) {
      whereClause = 'deleted = 0';
      whereArgs = [];
    }

    List<Map<String, dynamic>> maps = await db.query(
      tasksTable,
      where: whereClause,
      whereArgs: whereArgs,
    );

    List<Task> allTasks = List.generate(maps.length, (i) => Task.fromMap(maps[i]));
    final targetDate = DateTime(date.year, date.month, date.day);

    return allTasks.where((task) {
      final taskCreatedDate = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
      if (targetDate.isBefore(taskCreatedDate)) return false;

      if (task.type == TaskType.temporary) {
        return targetDate.isAtSameMomentAs(taskCreatedDate);
      } else if (task.type == TaskType.daily) {
        if (task.isPerpetual) return true;
        final expirationDate = taskCreatedDate.add(Duration(days: task.durationDays));
        return targetDate.isBefore(expirationDate);
      }
      return false;
    }).toList();
  }

  Future<List<Task>> getAllTasks({bool includeArchived = true}) async {
    Database db = await instance.database;
    String whereClause = includeArchived ? 'deleted = 0' : 'deleted = 0 AND is_active = ?';
    List<dynamic> whereArgs = includeArchived ? [] : [1];

    List<Map<String, dynamic>> maps = await db.query(
      tasksTable,
      where: whereClause,
      whereArgs: whereArgs,
    );
    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  Future<List<Task>> getArchivedTasks() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tasksTable,
      where: 'deleted = 0 AND is_active = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  Future<Task?> findDuplicateTask(String name) async {
    final all = await getAllTasks(includeArchived: false);
    final searchName = name.toLowerCase().trim();
    try {
      return all.firstWhere((t) => t.name.toLowerCase().trim() == searchName);
    } catch (_) {
      return null;
    }
  }

  // --- DayRecord Management ---
  // FIX 2: Entire method (STEP 1-3) wrapped in transaction for atomicity.
  Future<int> createOrUpdateDayRecord(DayRecord record) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dateStr = record.date;

    final result = await _writeLock.synchronized<int>(() async {
      Database db = await instance.database;
      late int resultValue;

      await db.transaction((txn) async {
        // STEP 1: Diff current task_status rows (non-deleted) to find what to insert/update/tombstone
        final existingStatus = await txn.query(
          taskStatusTable,
          where: 'date = ? AND deleted = 0',
          whereArgs: [dateStr],
        );
        final existingSids =
            existingStatus.map((r) => r['task_sid'] as String).toSet();
        final newCompletedSids = record.completedTaskIds.toSet();
        final newSkippedSids = record.skippedTaskIds.toSet()
          ..removeAll(record.completedTaskIds);
        final newAllSids = {...newCompletedSids, ...newSkippedSids};

        // Insert/update completed and skipped rows
        for (var sid in newCompletedSids) {
          await txn.execute('''
          INSERT OR REPLACE INTO $taskStatusTable
          (date, task_sid, status, updated_at, deleted, dirty)
          VALUES (?, ?, 'completed', ?, 0, 1)
        ''', [dateStr, sid, now]);
        }
        for (var sid in newSkippedSids) {
          await txn.execute('''
          INSERT OR REPLACE INTO $taskStatusTable
          (date, task_sid, status, updated_at, deleted, dirty)
          VALUES (?, ?, 'skipped', ?, 0, 1)
        ''', [dateStr, sid, now]);
        }

        // Tombstone sids no longer present
        for (var sid in existingSids) {
          if (!newAllSids.contains(sid)) {
            await txn.execute('''
            UPDATE $taskStatusTable
            SET deleted = 1, updated_at = ?, dirty = 1
            WHERE date = ? AND task_sid = ?
          ''', [now, dateStr, sid]);
          }
        }

        // STEP 2: Upsert day_meta
        await txn.execute('''
        INSERT OR REPLACE INTO $dayMetaTable
        (date, cheat_used, pomodoro_sessions, pomodoro_goal, updated_at, deleted, dirty)
        VALUES (?, ?, ?, ?, ?, 0, 1)
      ''', [
          dateStr,
          record.cheatUsed ? 1 : 0,
          record.pomodoroSessionsCompleted,
          record.pomodoroGoal,
          now,
        ]);

        // STEP 3: Write the derived day_records cache row
        int count = await txn.update(
          dayRecordsTable,
          record.toMap(),
          where: 'date = ?',
          whereArgs: [dateStr],
        );
        if (count == 0) {
          resultValue = await txn.insert(dayRecordsTable, record.toMap());
        } else {
          resultValue = count;
        }
      });

      return resultValue;
    });

    _notifyLocalChange();
    return result;
  }

  Future<DayRecord?> getDayRecord(String date) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      dayRecordsTable,
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isNotEmpty) {
      return DayRecord.fromMap(maps.first);
    }
    return null;
  }

  Future<List<DayRecord>> getDayRecords({int limit = 365}) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      dayRecordsTable,
      orderBy: 'date DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) {
      return DayRecord.fromMap(maps[i]);
    });
  }

  Future<List<DayRecord>> getTaskHistory(String taskSid) async {
    Database db = await instance.database;

    // Dates this task was completed/skipped, from the normalized task_status
    // table — no CSV LIKE, no spurious cheat-day matches.
    final statusRows = await db.query(
      taskStatusTable,
      columns: ['date'],
      distinct: true,
      where: 'task_sid = ? AND deleted = 0',
      whereArgs: [taskSid],
    );
    if (statusRows.isEmpty) return [];

    final dates = statusRows.map((r) => r['date'] as String).toList();
    final placeholders = List.filled(dates.length, '?').join(',');

    final maps = await db.query(
      dayRecordsTable,
      where: 'date IN ($placeholders)',
      whereArgs: dates,
      orderBy: 'date ASC',
    );
    return maps.map((m) => DayRecord.fromMap(m)).toList();
  }

  // --- Cheat Day Management ---
  Future<int> getCheatDaysUsed(String yearMonth) async {
    final db = await database;
    final result = await db.query(
      monthlyUsageTable,
      where: 'year_month = ?',
      whereArgs: [yearMonth],
    );
    if (result.isNotEmpty) {
      return result.first['cheat_days_used'] as int;
    }
    return 0;
  }

  Future<void> incrementCheatDaysUsed(String yearMonth) async {
    final db = await database;
    final currentUsed = await getCheatDaysUsed(yearMonth);

    final result = await db.query(
      monthlyUsageTable,
      where: 'year_month = ?',
      whereArgs: [yearMonth],
    );

    if (result.isNotEmpty) {
      await db.update(
        monthlyUsageTable,
        {'cheat_days_used': currentUsed + 1},
        where: 'year_month = ?',
        whereArgs: [yearMonth],
      );
    } else {
      await db.insert(
        monthlyUsageTable,
        {'year_month': yearMonth, 'cheat_days_used': 1},
      );
    }
  }

  Future<void> decrementCheatDaysUsed(String yearMonth) async {
    final db = await database;
    final currentUsed = await getCheatDaysUsed(yearMonth);
    if (currentUsed > 0) {
      await db.update(
        monthlyUsageTable,
        {'cheat_days_used': currentUsed - 1},
        where: 'year_month = ?',
        whereArgs: [yearMonth],
      );
    }
  }
}
