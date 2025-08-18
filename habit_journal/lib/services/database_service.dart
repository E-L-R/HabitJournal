// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:habit_journal/models/note.dart';
import 'package:habit_journal/models/habit.dart';
import 'package:habit_journal/models/habit_completion.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'app_database.db');

    return await openDatabase(
      dbPath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        frequency TEXT NOT NULL,
        goalAmount REAL,
        unit TEXT,
        type INTEGER NOT NULL DEFAULT 1,
        lastChecked INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_completions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        date INTEGER NOT NULL,
        loggedAmount REAL NOT NULL,
        isSuccess INTEGER NOT NULL,
        FOREIGN KEY (habitId) REFERENCES habits(id) ON DELETE CASCADE,
        UNIQUE (habitId, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');

    print('Tables created successfully!');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Step 1: Add isBinary column for the first upgrade
      await db.execute('ALTER TABLE habits ADD COLUMN isBinary INTEGER NOT NULL DEFAULT 0;');
      print('Upgraded database to version 2: Added isBinary column.');
    }
    if (oldVersion < 3) {
      // Step 2: Migrate isBinary column to the new type column
      await db.execute('ALTER TABLE habits ADD COLUMN type INTEGER NOT NULL DEFAULT 1;');
      await db.execute('UPDATE habits SET type = 0 WHERE isBinary = 1;');
      await db.execute('UPDATE habits SET type = 1 WHERE isBinary = 0;');
      await db.execute('ALTER TABLE habits RENAME COLUMN isBinary TO isBinaryOld;');
      print('Upgraded database to version 3: Migrated isBinary to new type column.');
    }
  }

  // --- CRUD Operations for Habits ---

  Future<int> insertHabit(Habit habit) async {
    Database db = await instance.database;
    return await db.insert(
      'habits',
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Habit>> getHabits() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('habits');
    return List.generate(maps.length, (i) {
      return Habit.fromMap(maps[i]);
    });
  }

  Future<int> updateHabit(Habit habit) async {
    Database db = await instance.database;
    return await db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteHabit(int id) async {
    Database db = await instance.database;
    return await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations for HabitCompletions ---

  int _getStartOfDayTimestamp(DateTime dateTime) {
    return DateTime.utc(
      dateTime.year,
      dateTime.month,
      dateTime.day,
    ).millisecondsSinceEpoch;
  }

  Future<int> logHabitCompletion({
    required int habitId,
    required double loggedAmount,
    DateTime? date,
  }) async {
    Database db = await instance.database;

    final List<Map<String, dynamic>> habitMaps = await db.query(
      'habits',
      where: 'id = ?',
      whereArgs: [habitId],
    );

    if (habitMaps.isEmpty) {
      throw Exception('Habit with ID $habitId not found.');
    }
    final Habit habit = Habit.fromMap(habitMaps.first);

    final bool isSuccess;
    if (habit.type == HabitType.binary) {
      isSuccess = loggedAmount >= 1.0;
    } else {
      isSuccess = loggedAmount >= (habit.goalAmount ?? 0.0);
    }

    final int dateTimestamp = _getStartOfDayTimestamp(date ?? DateTime.now());

    final HabitCompletion completion = HabitCompletion(
      habitId: habitId,
      date: dateTimestamp,
      loggedAmount: loggedAmount,
      isSuccess: isSuccess,
    );

    return await db.insert(
      'habit_completions',
      completion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HabitCompletion>> getHabitCompletionsForHabit(int habitId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'habit_completions',
      where: 'habitId = ?',
      whereArgs: [habitId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return HabitCompletion.fromMap(maps[i]);
    });
  }

  Future<HabitCompletion?> getHabitCompletionForDate(
    int habitId,
    DateTime date,
  ) async {
    Database db = await instance.database;
    final int dateTimestamp = _getStartOfDayTimestamp(date);
    final List<Map<String, dynamic>> maps = await db.query(
      'habit_completions',
      where: 'habitId = ? AND date = ?',
      whereArgs: [habitId, dateTimestamp],
    );
    if (maps.isNotEmpty) {
      return HabitCompletion.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateHabitCompletion(HabitCompletion completion) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> habitMaps = await db.query(
      'habits',
      where: 'id = ?',
      whereArgs: [completion.habitId],
    );
    if (habitMaps.isEmpty) {
      throw Exception('Habit with ID ${completion.habitId} not found.');
    }
    final Habit habit = Habit.fromMap(habitMaps.first);

    if (habit.type == HabitType.binary) {
      completion.isSuccess = completion.loggedAmount >= 1.0;
    } else {
      completion.isSuccess = completion.loggedAmount >= (habit.goalAmount ?? 0.0);
    }

    return await db.update(
      'habit_completions',
      completion.toMap(),
      where: 'id = ?',
      whereArgs: [completion.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteHabitCompletion(int id) async {
    Database db = await instance.database;
    return await db.delete(
      'habit_completions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CRUD Operations for Notes (unchanged) ---

  Future<int> insertNote(Note note) async {
    Database db = await instance.database;
    return await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Note>> getNotes() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('notes');
    return List.generate(maps.length, (i) {
      return Note.fromMap(maps[i]);
    });
  }

  Future<int> updateNote(Note note) async {
    Database db = await instance.database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteNote(int id) async {
    Database db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}