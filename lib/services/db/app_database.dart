import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'dish_entry.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'food_diary.db';
  static const _dbVersion = 2; // bump version

  static const dishTable = 'dish_entries';
  static const intakeTable = 'daily_intake';

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,

      // ✅ ENABLE FOREIGN KEYS HERE
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: (db, version) async {
        await db.execute('''
      CREATE TABLE $dishTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        calories INTEGER NOT NULL,
        cuisine TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

        await db.execute('''
      CREATE TABLE $intakeTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dish_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(dish_id) REFERENCES $dishTable(id) ON DELETE CASCADE
      )
    ''');
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
        CREATE TABLE $intakeTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dish_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY(dish_id) REFERENCES $dishTable(id) ON DELETE CASCADE
        )
      ''');
        }
      },
    );

    return _db!;
  }

  Future<int> insertDish(DishEntry entry) async {
    final db = await database;
    return db.insert(dishTable, entry.toMap());
  }

  Future<void> deleteDish(DishEntry entry) async {
    final db = await database;

    if (entry.id == null) return;

    // 1) Delete row from dish_entries table
    await db.delete(
      dishTable,
      where: 'id = ?',
      whereArgs: [entry.id],
    );

    final path = entry.imagePath.trim();

    // 2) Delete local image file
    if (path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // ignore file errors
        }
      }

      // 3) Clear cache (safe even if not cached)
      try {
        await DefaultCacheManager().removeFile(path);
      } catch (_) {}
    }
  }

  Future<List<DishEntry>> getAllDishes() async {
    final db = await database;
    final rows = await db.query(dishTable, orderBy: 'id DESC');
    return rows.map((e) => DishEntry.fromMap(e)).toList();
  }

  Future<DishEntry?> getDishById(int id) async {
    final db = await database;
    final rows = await db.query(dishTable, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return DishEntry.fromMap(rows.first);
  }

  // -------- Daily intake --------

  Future<int> addIntake({required int dishId, required String dateKey, int quantity = 1}) async {
    final db = await database;
    return db.insert(intakeTable, {
      'dish_id': dishId,
      'date': dateKey,
      'quantity': quantity,
    });
  }

  Future<void> removeIntake(int intakeId) async {
    final db = await database;
    await db.delete(intakeTable, where: 'id = ?', whereArgs: [intakeId]);
  }

  Future<List<Map<String, Object?>>> getDailyIntakeRaw(String dateKey) async {
    final db = await database;
    // Join to get dish info
    return db.rawQuery('''
      SELECT i.id as intake_id, i.quantity, d.*
      FROM $intakeTable i
      JOIN $dishTable d ON d.id = i.dish_id
      WHERE i.date = ?
      ORDER BY i.id DESC
    ''', [dateKey]);
  }
}