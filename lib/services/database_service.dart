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
      version: 2, // Increased version
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $usersTable (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tasksTable (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        duration_days INTEGER NOT NULL,
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
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE $dayRecordsTable ADD COLUMN skipped_task_ids TEXT DEFAULT ''");
    }
  }

  // --- User Management ---
  Future<int> createUser(User user) async {
    Database db = await instance.database;
    return await db.insert(usersTable, user.toMap());
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

  // New method to check if any user exists
  Future<bool> hasUser() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(usersTable, limit: 1);
    return maps.isNotEmpty;
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
    // This method will need more complex logic later to determine active tasks based on date and duration.
    // For now, return all active tasks.
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tasksTable,
      where: 'is_active = ?',
      whereArgs: [1], // Assuming 1 for true, 0 for false
    );
    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  // New method to get all tasks
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
    // Attempt to update, if no rows affected, then insert
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
      orderBy: 'date DESC', // Get most recent records first
      limit: limit,
    );
    return List.generate(maps.length, (i) {
      return DayRecord.fromMap(maps[i]);
    });
  }
}
