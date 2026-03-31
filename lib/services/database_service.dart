// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
  final String dayRecordsTable = 'day_records';
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
      version: 7,
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
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        duration_days INTEGER NOT NULL,
        is_perpetual INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL,
        frequency_type TEXT DEFAULT 'daily',
        weekly_target INTEGER DEFAULT 1
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
    return await db.insert(tasksTable, task.toMap());
  }

  Future<int> updateTask(Task task) async {
    Database db = await instance.database;
    return await db.update(
      tasksTable,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> archiveTask(int id) async {
    Database db = await instance.database;
    return await db.update(
      tasksTable,
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> unarchiveTask(int id) async {
    Database db = await instance.database;
    return await db.update(
      tasksTable,
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTaskPermanently(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tasksTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Task>> getActiveTasksForDate(DateTime date, {bool includeArchived = false}) async {
    Database db = await instance.database;
    
    String whereClause = 'is_active = ?';
    List<dynamic> whereArgs = [1];
    
    if (includeArchived) {
      whereClause = '1 = 1';
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
    String whereClause = includeArchived ? '1 = 1' : 'is_active = ?';
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
      where: 'is_active = ?',
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
    int count = await db.update(
      dayRecordsTable,
      record.toMap(),
      where: 'date = ?',
      whereArgs: [record.date],
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

  Future<List<DayRecord>> getTaskHistory(int taskId) async {
    Database db = await instance.database;
    final String tId = taskId.toString();

    List<Map<String, dynamic>> maps = await db.query(
      dayRecordsTable,
      where: "completed_task_ids LIKE ? OR skipped_task_ids LIKE ? OR cheat_used = 1",
      whereArgs: ['%$tId%', '%$tId%'],
      orderBy: 'date ASC',
    );

    return List.generate(maps.length, (i) {
      return DayRecord.fromMap(maps[i]);
    });
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

    // A. Daily Habits (Perpetual)
    final habits = [
      Task(id: 1, name: 'Morning Meditation', type: TaskType.daily, durationDays: 0, isPerpetual: true, createdAt: startDate),
      Task(id: 2, name: 'Reading (30m)', type: TaskType.daily, durationDays: 0, isPerpetual: true, createdAt: startDate),
      Task(id: 3, name: 'Journaling', type: TaskType.daily, durationDays: 0, isPerpetual: true, createdAt: startDate.add(const Duration(days: 30))),
    ];

    // B. Weekly Tasks (Flexible)
    final weeklyTasks = [
      Task(id: 4, name: 'Gym Workout', type: TaskType.daily, frequencyType: FrequencyType.weekly, weeklyTarget: 3, durationDays: 0, isPerpetual: true, createdAt: startDate),
      Task(id: 5, name: 'Weekly Review', type: TaskType.daily, frequencyType: FrequencyType.weekly, weeklyTarget: 1, durationDays: 0, isPerpetual: true, createdAt: startDate),
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
          id: 1000 + i,
          name: 'Temp Task $i',
          type: TaskType.temporary,
          durationDays: 1,
          isPerpetual: false,
          createdAt: currentDate,
        );
        await addTask(tempTask);
        activeTasksForDay.add(tempTask);
      }

      List<int> completedIds = [];
      List<int> skippedIds = [];
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
            completedIds.add(task.id);
          } else if (random.nextDouble() < 0.2) {
            skippedIds.add(task.id);
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
