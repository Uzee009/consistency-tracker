// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // For getting the application documents directory
import 'dart:io'; // For Directory

import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._constructor();

  final String usersTable = 'users';
  final String tasksTable = 'tasks';
  final String dayRecordsTable = 'day_records';
  final String monthlyUsageTable = 'monthly_usage'; // New table

  DatabaseService._constructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'consistency_tracker.db');
    return await openDatabase(
      path,
      version: 5, // Increased version for monthly_usage table
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
        is_active INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $dayRecordsTable (
        date TEXT PRIMARY KEY,
        completed_task_ids TEXT NOT NULL,
        skipped_task_ids TEXT NOT NULL,
        cheat_used INTEGER NOT NULL,
        completion_score REAL NOT NULL,
        visual_state TEXT NOT NULL
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

  Future<int> deleteTask(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tasksTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Task>> getActiveTasksForDate(DateTime date) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tasksTable,
      where: 'is_active = ?',
      whereArgs: [1],
    );

    List<Task> allTasks = List.generate(maps.length, (i) => Task.fromMap(maps[i]));
    
    return allTasks.where((task) {
      if (task.type == TaskType.temporary) {
        return task.createdAt.year == date.year &&
               task.createdAt.month == date.month &&
               task.createdAt.day == date.day;
      } else if (task.type == TaskType.daily) {
        if (task.isPerpetual) {
          return true;
        }
        final expirationDate = task.createdAt.add(Duration(days: task.durationDays));
        return date.isBefore(expirationDate);
      }
      return false;
    }).toList();
  }

  Future<List<Task>> getAllTasks() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(tasksTable);
    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
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
    if (currentUsed > 0) {
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
}
