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
      version: 1,
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade, // Uncomment and implement if you need to handle schema changes in future versions
    );
  }

  // This method is called when the database is first created
  Future<void> _onCreate(Database db, int version) async {
    // Create the Habits table with new goal and unit columns
    await db.execute('''
      CREATE TABLE habits(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        frequency TEXT NOT NULL,
        goalAmount REAL NOT NULL, -- New: The target amount
        unit TEXT NOT NULL,      -- New: The unit of the goal
        lastChecked INTEGER      -- Unix timestamp for last overall interaction
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

  // Example for handling database upgrades (e.g., adding new columns)
  // Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  //   if (oldVersion < 2) {
  //     // Example: If you needed to add a new column 'description' to habits in version 2
  //     await db.execute('ALTER TABLE habits ADD COLUMN description TEXT;');
  //   }
  //   // Add more upgrade logic for other versions as needed
  // }

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
  // This method handles the logic of determining success based on the habit's goal
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
    final double goalAmount = habit.goalAmount;

    final int dateTimestamp = _getStartOfDayTimestamp(date ?? DateTime.now());
    final bool isSuccess = loggedAmount >= goalAmount;

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

    // Re-calculate isSuccess in case loggedAmount changed relative to habit's goal
    final List<Map<String, dynamic>> habitMaps = await db.query(
      'habits',
      where: 'id = ?',
      whereArgs: [completion.habitId],
    );
    if (habitMaps.isEmpty) {
      throw Exception('Habit with ID ${completion.habitId} not found.');
    }
    final Habit habit = Habit.fromMap(habitMaps.first);
    completion.isSuccess = completion.loggedAmount >= habit.goalAmount;

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

// How to use it in your Flutter app:
// import 'package:flutter/material.dart'; // Needed for WidgetsFlutterBinding

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   final dbHelper = DatabaseHelper.instance;
//   await dbHelper.database; // This will trigger _onCreate if the database doesn't exist
//   print('Database opened and tables ensured.');

//   // --- Example Usage for Habits ---
//   print('\n--- Habit Operations (Enhanced) ---');
//   // Insert a new habit with goal and unit
//   final newHabitId = await dbHelper.insertHabit(Habit(
//     name: 'Drink Water',
//     frequency: 'daily',
//     goalAmount: 2.0, // Goal: 2 liters
//     unit: 'liters',
//     lastChecked: DateTime.now().millisecondsSinceEpoch,
//   ));
//   print('Inserted habit with ID: $newHabitId');

//   // Get all habits
//   List<Habit> habits = await dbHelper.getHabits();
//   print('All habits: $habits');

//   // Log a completion for the new habit
//   if (newHabitId > 0) {
//     await dbHelper.logHabitCompletion(habitId: newHabitId, loggedAmount: 1.5); // Not successful yet (1.5 < 2.0)
//     print('Logged 1.5 liters for habit ID $newHabitId');
//     await dbHelper.logHabitCompletion(habitId: newHabitId, loggedAmount: 2.5); // Successful (2.5 >= 2.0)
//     print('Logged 2.5 liters for habit ID $newHabitId'); // This will replace the previous log for today

//     List<HabitCompletion> completions = await dbHelper.getHabitCompletionsForHabit(newHabitId);
//     print('Completions for habit ID $newHabitId: $completions');

//     // Log completion for a past date (for demonstration)
//     final yesterday = DateTime.now().subtract(Duration(days: 1));
//     await dbHelper.logHabitCompletion(habitId: newHabitId, loggedAmount: 3.0, date: yesterday);
//     print('Logged 3.0 liters for yesterday for habit ID $newHabitId');
//     completions = await dbHelper.getHabitCompletionsForHabit(newHabitId);
//     print('Completions for habit ID $newHabitId: $completions');

//     // Get specific completion
//     final todaysCompletion = await dbHelper.getHabitCompletionForDate(newHabitId, DateTime.now());
//     print('Today\'s completion for habit ID $newHabitId: $todaysCompletion');
//   }

//   // Update a habit
//   if (habits.isNotEmpty) {
//     Habit firstHabit = habits.first;
//     firstHabit.name = 'Drink 8 Glasses of Water';
//     firstHabit.goalAmount = 8.0;
//     firstHabit.unit = 'glasses';
//     await dbHelper.updateHabit(firstHabit);
//     print('Updated first habit. New list: ${await dbHelper.getHabits()}');
//   }

//   // Delete a habit
//   if (habits.isNotEmpty) {
//     await dbHelper.deleteHabit(habits.first.id!);
//     print('Deleted first habit. New list: ${await dbHelper.getHabits()}');
//   }

//   // --- Example Usage for Notes (unchanged) ---
//   print('\n--- Note Operations ---');
//   final newNoteId = await dbHelper.insertNote(Note(title: 'Grocery List', content: 'Milk, Eggs, Bread', timestamp: DateTime.now().millisecondsSinceEpoch));
//   print('Inserted note with ID: $newNoteId');
//   List<Note> notes = await dbHelper.getNotes();
//   print('All notes: $notes');
//   if (notes.isNotEmpty) {
//     Note firstNote = notes.first;
//     firstNote.content = 'Milk, Eggs, Bread, Cheese';
//     await dbHelper.updateNote(firstNote);
//     print('Updated first note. New list: ${await dbHelper.getNotes()}');
//   }
//   if (notes.isNotEmpty) {
//     await dbHelper.deleteNote(notes.first.id!);
//     print('Deleted first note. New list: ${await dbHelper.getNotes()}');
//   }
// }
