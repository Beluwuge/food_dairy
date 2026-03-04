import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'dish_entry.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'food_diary.db';
  static const _dbVersion = 3; // ✅ bump to 3

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

      // ✅ Required for CASCADE to work
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $dishTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
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

        // Optional indexes
        await db.execute('CREATE INDEX idx_dish_username ON $dishTable(username)');
        await db.execute('CREATE INDEX idx_intake_date ON $intakeTable(date)');
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2 created intake table (your previous upgrade)
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
          await db.execute('CREATE INDEX idx_intake_date ON $intakeTable(date)');
        }

        // ✅ v2 -> v3 add username to dish_entries
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $dishTable ADD COLUMN username TEXT NOT NULL DEFAULT "legacy"');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_dish_username ON $dishTable(username)');
        }
      },
    );

    return _db!;
  }

  // ---------------- Dishes (Posts) ----------------

  Future<int> insertDish(DishEntry entry) async {
    final db = await database;
    return db.insert(dishTable, entry.toMap());
  }

  // ✅ NEW: per-user posts
  Future<List<DishEntry>> getDishesByUser(String username) async {
    final db = await database;
    final rows = await db.query(
      dishTable,
      where: 'username = ?',
      whereArgs: [username],
      orderBy: 'id DESC',
    );
    return rows.map(DishEntry.fromMap).toList();
  }

  // (Optional) keep global fetch if you still need it somewhere
  Future<List<DishEntry>> getAllDishes() async {
    final db = await database;
    final rows = await db.query(dishTable, orderBy: 'id DESC');
    return rows.map(DishEntry.fromMap).toList();
  }

  Future<int> updateDish(DishEntry entry) async {
    final db = await database;
    if (entry.id == null) throw Exception('Dish id is null');
    return db.update(
      dishTable,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  // ✅ Delete dish + file + cache + intake cleanup fallback
  Future<void> deleteDish(DishEntry entry) async {
    final db = await database;
    final id = entry.id;
    if (id == null) return;

    // Fallback delete intake rows (safe even if CASCADE is enabled)
    await db.delete(intakeTable, where: 'dish_id = ?', whereArgs: [id]);

    // Delete dish row
    await db.delete(dishTable, where: 'id = ?', whereArgs: [id]);

    // Delete local image file
    final imagePath = entry.imagePath.trim();
    if (imagePath.isNotEmpty) {
      final f = File(imagePath);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }

      // Clear cache (if any)
      try {
        await DefaultCacheManager().removeFile(imagePath);
      } catch (_) {}
    }
  }

  // ---------------- Daily Intake ----------------

  Future<int> addIntake({
    required int dishId,
    required String dateKey,
    int quantity = 1,
  }) async {
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

  // ✅ NEW: intake filtered by username (JOIN on dish_entries.username)
  Future<List<Map<String, Object?>>> getDailyIntakeRawForUser({
    required String username,
    required String dateKey,
  }) async {
    final db = await database;
    return db.rawQuery('''
      SELECT i.id as intake_id, i.quantity, d.*
      FROM $intakeTable i
      JOIN $dishTable d ON d.id = i.dish_id
      WHERE i.date = ?
        AND d.username = ?
      ORDER BY i.id DESC
    ''', [dateKey, username]);
  }
}