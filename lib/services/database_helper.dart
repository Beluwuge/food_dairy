import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  static Database? _db;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'food_dairy.db');

    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE diary_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_blob BLOB NOT NULL,
        comment TEXT,
        created_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        age INTEGER,
        weight REAL,
        height REAL
      );
    ''');
    await db.execute('''
      CREATE TABLE water_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_iso TEXT UNIQUE,
        ml INTEGER
      );
    ''');
  }

  Future<int> insertDiaryEntry({
    required Uint8List imageBytes,
    required String comment,
    required int createdAt,
  }) async {
    final db = await database;
    return db.insert('diary_entries', {
      'image_blob': imageBytes,
      'comment': comment,
      'created_at': createdAt,
    });
  }

  Future<List<Map<String, dynamic>>> getDiaryEntries() async {
    final db = await database;
    return db.query('diary_entries', orderBy: 'created_at DESC');
  }

  Future<int> deleteDiaryEntry(int id) async {
    final db = await database;
    return db.delete('diary_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertOrUpdateProfile({
    required String name,
    required int age,
    required double weight,
    required double height,
  }) async {
    final db = await database;
    final existing = await db.query('user_profile', limit: 1);

    if (existing.isNotEmpty) {
      return db.update('user_profile', {
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
      });
    } else {
      return db.insert('user_profile', {
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getProfile() async {
    final db = await database;
    return db.query('user_profile', limit: 1);
  }

  Future<int> setWater({
    required String dateIso,
    required int ml,
  }) async {
    final db = await database;
    return db.insert('water_logs', {
      'date_iso': dateIso,
      'ml': ml,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getWater(String dateIso) async {
    final db = await database;
    return db.query('water_logs', where: 'date_iso = ?', whereArgs: [dateIso]);
  }
}
