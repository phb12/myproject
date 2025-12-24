// lib/services/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;

import '../models/workout_log_model.dart';
import '../models/user_model.dart';
import '../models/weight_log_model.dart';
import '../models/set_log_model.dart';
import '../models/custom_exercise.dart';
import '../models/exercise_model.dart';
import '../models/plan_item_model.dart'; 
import '../services/firestore_service.dart'; 

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();
  static Database? _db;

  Future<Database> get db async => _db ??= await initDB();

  Future<Database> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'data.db');
    return await openDatabase(
      path,
      version: 15, 
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account TEXT UNIQUE, password TEXT, height TEXT, weight TEXT,
        age TEXT, bmi TEXT, fat TEXT, gender TEXT, bmr TEXT,
        goalWeight TEXT, fitnessLevel TEXT, trainingDays TEXT,
        nickname TEXT, hometown TEXT, photoUrl TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exerciseName TEXT, totalSets INTEGER,
        completedAt TEXT, bodyPart TEXT,
        account TEXT,
        calories REAL DEFAULT 0,
        avg_heart_rate INTEGER DEFAULT 0,
        max_heart_rate INTEGER DEFAULT 0

      )
    ''');
    // 【修正】加上逗號
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weight REAL NOT NULL, 
        createdAt TEXT NOT NULL,
        account TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS set_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutLogId INTEGER, setNumber INTEGER,
        weight REAL, reps INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bodyPart INTEGER,
        name TEXT NOT NULL,
        description TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dayOfWeek INTEGER NOT NULL,
        exerciseName TEXT NOT NULL,
        sets TEXT NOT NULL,
        weight TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      try { await db.execute('ALTER TABLE workout_logs ADD COLUMN bodyPart TEXT'); } catch (_) {}
    }
    if (oldVersion < 4) {
      // 【修正】加上逗號
      await db.execute('''
        CREATE TABLE IF NOT EXISTS weight_logs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          weight REAL NOT NULL, 
          createdAt TEXT NOT NULL,
          account TEXT
        )
      ''');
    }
    if (oldVersion < 14) {
      try {
        await db.execute('ALTER TABLE workout_logs ADD COLUMN calories REAL DEFAULT 0');
        await db.execute('ALTER TABLE workout_logs ADD COLUMN avg_heart_rate INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE workout_logs ADD COLUMN max_heart_rate INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE users ADD COLUMN goalWeight TEXT'); } catch (_) {}
    }
    if (oldVersion < 6) {
      try { await db.execute('ALTER TABLE users ADD COLUMN fitnessLevel TEXT'); } catch (_) {}
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS set_logs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          workoutLogId INTEGER, setNumber INTEGER,
          weight REAL, reps INTEGER
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS custom_exercises (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bodyPart INTEGER,
          name TEXT NOT NULL,
          description TEXT
        )
      ''');
      try { await db.execute('ALTER TABLE users ADD COLUMN trainingDays TEXT'); } catch (_) {}
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS plan_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dayOfWeek INTEGER NOT NULL,
          exerciseName TEXT NOT NULL,
          sets TEXT NOT NULL,
          weight TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 11) {
       try { await db.execute('ALTER TABLE users ADD COLUMN nickname TEXT'); } catch (_) {}
       try { await db.execute('ALTER TABLE users ADD COLUMN hometown TEXT'); } catch (_) {}
    }
    if (oldVersion < 15) {
       try { await db.execute('ALTER TABLE users ADD COLUMN photoUrl TEXT'); } catch (_) {}
    }
    if (oldVersion < 12) {
       try { await db.execute('ALTER TABLE workout_logs ADD COLUMN account TEXT'); } catch (_) {}
    }
    // 【修正】正確的括號結構
    if (oldVersion < 13) {
       try { await db.execute('ALTER TABLE weight_logs ADD COLUMN account TEXT'); } catch (_) {}
    }
  }

  // --- User 相關方法 ---
  Future<void> insertUser(Map<String, dynamic> data) async {
    final db = await instance.db;
    await db.insert('users', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> validateUser(String account, String password) async {
    final db = await instance.db;
    final result = await db.query('users', where: 'account = ? AND password = ?', whereArgs: [account, password]);
    return result.isNotEmpty;
  }

  Future<User?> getUserByAccount(String account) async {
    final db = await instance.db;
    final List<Map<String, dynamic>> maps = await db.query('users', where: 'account = ?', whereArgs: [account], limit: 1);
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  } 

  Future<int> updateUser(User user) async {
    final db = await instance.db;
    return await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  // --- CustomExercise 相關 ---
  Future<int> insertCustomExercise(CustomExercise exercise) async {
    final db = await instance.db;
    return await db.insert('custom_exercises', exercise.toMap());
  }

  Future<List<CustomExercise>> getCustomExercisesForBodyPart(BodyPart bodyPart) async {
    final db = await instance.db;
    final List<Map<String, dynamic>> maps = await db.query('custom_exercises', where: 'bodyPart = ?', whereArgs: [bodyPart.index]);
    return List.generate(maps.length, (i) => CustomExercise.fromMap(maps[i]));
  }

  Future<int> deleteCustomExercise(int id) async {
    final db = await instance.db;
    return await db.delete('custom_exercises', where: 'id = ?', whereArgs: [id]);
  }

  // --- WorkoutLog 相關方法 ---
  Future<int> insertWorkoutLog(WorkoutLog log, {bool syncToCloud = true}) async {
    final db = await instance.db;
    final id = await db.insert('workout_logs', log.toMap());
    
    // 只有在 syncToCloud 為 true 時才上傳
    if (syncToCloud) {
      FirestoreService.instance.saveWorkoutLog(log); 
    }
    
    return id;
  }

  Future<List<WorkoutLog>> getWorkoutLogs(String account) async {
    final db = await instance.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'workout_logs', 
      where: 'account = ?', 
      whereArgs: [account], 
      orderBy: 'completedAt DESC'
    );
    return List.generate(maps.length, (i) => WorkoutLog.fromMap(maps[i]));
  }

  Future<int> deleteAllWorkoutLogs(String account) async {
    final db = await instance.db;
    return await db.delete('workout_logs', where: 'account = ?', whereArgs: [account]);
  }

  // --- WeightLog 相關方法 ---
  Future<void> insertWeightLog(WeightLog log, {bool syncToCloud = true}) async {
    final db = await instance.db;
    final dateStr = log.createdAt.toIso8601String().substring(0, 10);
    await db.delete(
      'weight_logs', 
      where: 'createdAt LIKE ? AND account = ?', 
      whereArgs: ['$dateStr%', log.account]
    );
    await db.insert('weight_logs', log.toMap());
    
    if (syncToCloud) {
      FirestoreService.instance.saveWeightLog(log);
    }
  }

  Future<void> deleteWeightLogsForDate(DateTime date, String account) async {
      final db = await instance.db;
      final dateStr = date.toIso8601String().substring(0, 10);
      await db.delete(
        'weight_logs', 
        where: 'createdAt LIKE ? AND account = ?', 
        whereArgs: ['$dateStr%', account]
      );
  }

  Future<List<WeightLog>> getWeightLogs(String account) async {
    final db = await instance.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'weight_logs', 
      where: 'account = ?', 
      whereArgs: [account],
      orderBy: 'createdAt DESC'
    );
    return List.generate(maps.length, (i) => WeightLog.fromMap(maps[i]));
  }

  // --- SetLog 相關方法 ---
  Future<void> insertSetLog(SetLog log) async {
    final db = await instance.db;
    await db.insert('set_logs', log.toMap());
  }

  Future<List<SetLog>> getSetLogsForWorkout(int workoutLogId) async {
    final db = await instance.db;
    final List<Map<String, dynamic>> maps = await db.query('set_logs', where: 'workoutLogId = ?', whereArgs: [workoutLogId], orderBy: 'setNumber ASC');
    return List.generate(maps.length, (i) => SetLog.fromMap(maps[i]));
  }

  // --- PlanItem 相關方法 ---
  Future<int> insertPlanItem(PlanItem item) async {
    final db = await instance.db;
    return await db.insert('plan_items', item.toMap());
  }

  Future<List<PlanItem>> getPlanItemsForDay(int dayOfWeek) async {
    final db = await instance.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'plan_items',
      where: 'dayOfWeek = ?',
      whereArgs: [dayOfWeek],
    );
    return List.generate(maps.length, (i) => PlanItem.fromMap(maps[i]));
  }

  Future<int> deletePlanItem(int id) async {
    final db = await instance.db;
    return await db.delete('plan_items', where: 'id = ?', whereArgs: [id]);
  }
}