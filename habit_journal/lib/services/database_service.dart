import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:habit_journal/models/note.dart';
import 'package:habit_journal/models/habit.dart';
import 'package:habit_journal/models/habit_completion.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  // Getter for the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'app_database.db');

    return await openDatabase(
      dbPath,
      version: 2, // New: Incremented version to handle schema changes
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // New: Added onUpgrade to handle schema changes
    );
  }

  // This method is called when the database is first created
  Future<void> _onCreate(Database db, int version) async {
    // Create the Habits table with the new isBinary column
    await db.execute('''
      CREATE TABLE habits(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        frequency TEXT NOT NULL,
        goalAmount REAL, -- Made nullable for binary habits
        unit TEXT,      -- Made nullable for binary habits
        isBinary INTEGER NOT NULL DEFAULT 0, -- New: 0 for unit-based, 1 for binary
        lastChecked INTEGER
      )
    ''');

    // Create the HabitCompletions table
    await db.execute('''
      CREATE TABLE habit_completions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        date INTEGER NOT NULL,
        loggedAmount REAL NOT NULL,
        isSuccess INTEGER NOT NULL, -- 0 for false, 1 for true
        FOREIGN KEY (habitId) REFERENCES habits(id) ON DELETE CASCADE,
        UNIQUE (habitId, date) -- Ensures only one completion record per habit per day
      )
    ''');

    // Create the Notes table
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');

    print('Habits, HabitCompletions, and Notes tables created successfully!');
  }

  // Method to handle database schema upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add the new isBinary column to the habits table
      await db.execute('ALTER TABLE habits ADD COLUMN isBinary INTEGER NOT NULL DEFAULT 0;');
      print('Upgraded database to version 2: Added isBinary column to habits table.');
    }
  }

  // --- CRUD Operations for Habits ---

  // Create (Insert) a new habit
  Future<int> insertHabit(Habit habit) async {
    Database db = await instance.database;
    return await db.insert(
      'habits',
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Read (Retrieve) all habits
  Future<List<Habit>> getHabits() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('habits');
    return List.generate(maps.length, (i) {
      return Habit.fromMap(maps[i]);
    });
  }

  // Update an existing habit
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

  // Delete a habit by its ID (and associated completions due to ON DELETE CASCADE)
  Future<int> deleteHabit(int id) async {
    Database db = await instance.database;
    return await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations for HabitCompletions ---

  // Helper to get the start of the day in UTC milliseconds
  int _getStartOfDayTimestamp(DateTime dateTime) {
    return DateTime.utc(
      dateTime.year,
      dateTime.month,
      dateTime.day,
    ).millisecondsSinceEpoch;
  }

  // Insert or update a daily completion for a habit
  Future<int> logHabitCompletion({
    required int habitId,
    required double loggedAmount,
    DateTime? date, // Optional: defaults to today (UTC)
  }) async {
    Database db = await instance.database;

    // Get the habit's goal amount to determine success
    final List<Map<String, dynamic>> habitMaps = await db.query(
      'habits',
      where: 'id = ?',
      whereArgs: [habitId],
    );

    if (habitMaps.isEmpty) {
      throw Exception('Habit with ID $habitId not found.');
    }
    final Habit habit = Habit.fromMap(habitMaps.first);

    // New logic: determine success based on habit type
    final bool isSuccess;
    if (habit.isBinary) {
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
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Upsert: update if exists for that day
    );
  }

  // Get all completions for a specific habit
  Future<List<HabitCompletion>> getHabitCompletionsForHabit(int habitId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'habit_completions',
      where: 'habitId = ?',
      whereArgs: [habitId],
      orderBy: 'date DESC', // Order by most recent completions first
    );
    return List.generate(maps.length, (i) {
      return HabitCompletion.fromMap(maps[i]);
    });
  }

  // Get a specific completion for a habit on a specific date
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

  // Update an existing habit completion record
  Future<int> updateHabitCompletion(HabitCompletion completion) async {
    Database db = await instance.database;

    // Get the habit to determine its type and goal
    final List<Map<String, dynamic>> habitMaps = await db.query(
      'habits',
      where: 'id = ?',
      whereArgs: [completion.habitId],
    );
    if (habitMaps.isEmpty) {
      throw Exception('Habit with ID ${completion.habitId} not found.');
    }
    final Habit habit = Habit.fromMap(habitMaps.first);

    // New logic: Re-calculate isSuccess based on the habit type
    if (habit.isBinary) {
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

  // Delete a specific habit completion record
  Future<int> deleteHabitCompletion(int id) async {
    Database db = await instance.database;
    return await db.delete(
      'habit_completions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CRUD Operations for Notes (unchanged) ---

  // Create (Insert) a new note
  Future<int> insertNote(Note note) async {
    Database db = await instance.database;
    return await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Read (Retrieve) all notes
  Future<List<Note>> getNotes() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('notes');
    return List.generate(maps.length, (i) {
      return Note.fromMap(maps[i]);
    });
  }

  // Update an existing note
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

  // Delete a note by its ID
  Future<int> deleteNote(int id) async {
    Database db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}