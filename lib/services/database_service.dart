// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:math';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';
import '../services/scoring_service.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._constructor();

  final String usersTable = 'users';
  final String tasksTable = 'tasks';
  final String taskStatusTable = 'task_status';
  final String dayMetaTable = 'day_meta';
  final String dayRecordsTable = 'day_records'; // Local derived cache
  final String monthlyUsageTable = 'monthly_usage';

  DatabaseService._constructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String dbName = const String.fromEnvironment(
      'DATABASE_NAME', 
      defaultValue: 'consistency_tracker.db'
    );
    String path = join(documentsDirectory.path, dbName);
    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
    return await db.insert(tasksTable, taskMap);
  }

  Future<int> updateTask(Task task) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final taskMap = task.toMap();
    taskMap['updated_at'] = now;
    taskMap['dirty'] = 1;
    return await db.update(
      tasksTable,
      taskMap,
      where: 'sid = ?',
      whereArgs: [task.sid],
    );
  }

  Future<int> archiveTask(String sid) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      tasksTable,
      {'is_active': 0, 'updated_at': now, 'dirty': 1},
      where: 'sid = ?',
      whereArgs: [sid],
    );
  }

  Future<int> unarchiveTask(String sid) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      tasksTable,
      {'is_active': 1, 'updated_at': now, 'dirty': 1},
      where: 'sid = ?',
      whereArgs: [sid],
    );
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
    return 1;
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
  Future<int> createOrUpdateDayRecord(DayRecord record) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final dateStr = record.date;

    // STEP 1: Diff current task_status rows (non-deleted) to find what to insert/update/tombstone
    final existingStatus = await db.query(
      taskStatusTable,
      where: 'date = ? AND deleted = 0',
      whereArgs: [dateStr],
    );
    final existingSids = existingStatus.map((r) => r['task_sid'] as String).toSet();
    final newCompletedSids = record.completedTaskIds.toSet();
    final newSkippedSids = record.skippedTaskIds.toSet()
      ..removeAll(record.completedTaskIds);
    final newAllSids = {...newCompletedSids, ...newSkippedSids};

    // Insert/update completed and skipped rows
    for (var sid in newCompletedSids) {
      await db.execute('''
        INSERT OR REPLACE INTO $taskStatusTable
        (date, task_sid, status, updated_at, deleted, dirty)
        VALUES (?, ?, 'completed', ?, 0, 1)
      ''', [dateStr, sid, now]);
    }
    for (var sid in newSkippedSids) {
      await db.execute('''
        INSERT OR REPLACE INTO $taskStatusTable
        (date, task_sid, status, updated_at, deleted, dirty)
        VALUES (?, ?, 'skipped', ?, 0, 1)
      ''', [dateStr, sid, now]);
    }

    // Tombstone sids no longer present
    for (var sid in existingSids) {
      if (!newAllSids.contains(sid)) {
        await db.execute('''
          UPDATE $taskStatusTable
          SET deleted = 1, updated_at = ?, dirty = 1
          WHERE date = ? AND task_sid = ?
        ''', [now, dateStr, sid]);
      }
    }

    // STEP 2: Upsert day_meta
    await db.execute('''
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
    int count = await db.update(
      dayRecordsTable,
      record.toMap(),
      where: 'date = ?',
      whereArgs: [dateStr],
    );
    if (count == 0) {
      return await db.insert(dayRecordsTable, record.toMap());
    }
    return count;
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

  // --- Seeding Logic ---
  Future<void> seedData() async {
    final db = await database;

    // 1. Clear existing data
    await db.delete(usersTable);
    await db.delete(tasksTable);
    await db.delete(taskStatusTable);
    await db.delete(dayMetaTable);
    await db.delete(dayRecordsTable);
    await db.delete(monthlyUsageTable);

    // 2. Create Test User
    final user = User(
      id: 1,
      name: 'Test Pilot',
      createdAt: DateTime.now().subtract(const Duration(days: 200)),
      monthlyCheatDays: 3,
    );
    await createUser(user);

    // 3. Define Tasks
    final startDate = DateTime.now().subtract(const Duration(days: 180));
    final random = Random();
    const uuid = Uuid();

    // A. Daily Habits (Perpetual)
    final habits = [
      Task(sid: uuid.v4(), name: 'Morning Meditation', type: TaskType.daily, durationDays: 0, isPerpetual: true, createdAt: startDate),
      Task(sid: uuid.v4(), name: 'Reading (30m)', type: TaskType.daily, durationDays: 0, isPerpetual: true, createdAt: startDate),
      Task(sid: uuid.v4(), name: 'Journaling', type: TaskType.daily, durationDays: 0, isPerpetual: true, createdAt: startDate.add(const Duration(days: 30))),
    ];

    // B. Weekly Tasks (Flexible)
    final weeklyTasks = [
      Task(sid: uuid.v4(), name: 'Gym Workout', type: TaskType.daily, frequencyType: FrequencyType.weekly, weeklyTarget: 3, durationDays: 0, isPerpetual: true, createdAt: startDate),
      Task(sid: uuid.v4(), name: 'Weekly Review', type: TaskType.daily, frequencyType: FrequencyType.weekly, weeklyTarget: 1, durationDays: 0, isPerpetual: true, createdAt: startDate),
    ];

    for (var t in habits) { await addTask(t); }
    for (var t in weeklyTasks) { await addTask(t); }

    // 4. Generate 180 Days of Records
    List<DayRecord> history = [];
    final allPermanentTasks = [...habits, ...weeklyTasks];

    for (int i = 0; i < 180; i++) {
      final currentDate = startDate.add(Duration(days: i));
      final dateStr = currentDate.toIso8601String().split('T')[0];
      
      // Randomly add Temporary Tasks (approx every 3 days)
      List<Task> activeTasksForDay = List.from(allPermanentTasks.where((t) => !currentDate.isBefore(t.createdAt)));
      if (random.nextDouble() < 0.3) {
        final tempTask = Task(
          sid: uuid.v4(),
          name: 'Temp Task $i',
          type: TaskType.temporary,
          durationDays: 1,
          isPerpetual: false,
          createdAt: currentDate,
        );
        await addTask(tempTask);
        activeTasksForDay.add(tempTask);
      }

      List<String> completedIds = [];
      List<String> skippedIds = [];
      bool isCheatDay = false;

      // Decide if it's a cheat day (max 3 per month)
      final yearMonth = "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}";
      int cheatUsedThisMonth = history.where((r) => r.date.startsWith(yearMonth) && r.cheatUsed).length;
      if (cheatUsedThisMonth < 3 && random.nextDouble() < 0.05) {
        isCheatDay = true;
      }

      if (!isCheatDay) {
        for (var task in activeTasksForDay) {
          double completionProbability = 0.8;

          if (task.frequencyType == FrequencyType.weekly) {
            final progress = ScoringService.getWeeklyProgress(task, currentDate, history);
            if (progress.isGoalMet) {
              completionProbability = 0.1;
            } else if (progress.isRequiredToday) {
              completionProbability = 0.95;
            }
          }

          if (random.nextDouble() < completionProbability) {
            completedIds.add(task.sid);
          } else if (random.nextDouble() < 0.2) {
            skippedIds.add(task.sid);
          }
        }
      }

      final tempRecord = DayRecord(
        date: dateStr,
        completedTaskIds: completedIds,
        skippedTaskIds: skippedIds,
        cheatUsed: isCheatDay,
        pomodoroSessionsCompleted: random.nextInt(6),
        pomodoroGoal: 4,
      );

      final scoreResult = ScoringService.calculateDayScore(
        allTasks: activeTasksForDay,
        dayRecord: tempRecord,
        history: history,
      );

      final finalRecord = tempRecord.copyWith(
        completionScore: scoreResult.completionScore,
        visualState: scoreResult.visualState,
      );

      await createOrUpdateDayRecord(finalRecord);
      history.add(finalRecord);

      if (isCheatDay) {
        await incrementCheatDaysUsed(yearMonth);
      }
    }
  }
}
