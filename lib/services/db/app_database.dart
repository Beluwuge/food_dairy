import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'dish_entry.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'food_diary.db';
  static const _dbVersion = 1;

  static const dishTable = 'dish_entries';

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
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
      },
    );

    return _db!;
  }

  Future<int> insertDish(DishEntry entry) async {
    final db = await database;
    return db.insert(dishTable, entry.toMap());
  }

  Future<List<DishEntry>> getAllDishes() async {
    final db = await database;
    final rows = await db.query(dishTable, orderBy: 'id DESC');
    return rows.map((e) => DishEntry.fromMap(e)).toList();
  }
}