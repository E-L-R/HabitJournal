// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habit_journal/models/note.dart';
import 'package:habit_journal/models/habit.dart';
import 'package:habit_journal/models/habit_completion.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) {
      // Check if the current database path is for the currently logged-in user
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final currentDbPath = _database!.path;
      final expectedDbPath = await _getUserDbPath(currentUserId);

      // If the paths don't match, close the old database and open the new one
      if (currentDbPath != expectedDbPath) {
        await _database!.close();
        _database = await _initDatabase();
      }
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User is not logged in. Cannot initialize database.");
    }
    final path = await _getUserDbPath(user.uid);

    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<String> _getUserDbPath(String? userId) async {
    if (userId == null) {
      throw Exception("User ID is null. Cannot determine database path.");
    }
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, '${userId}_app_database.db');
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
      await db.execute('ALTER TABLE habits ADD COLUMN isBinary INTEGER NOT NULL DEFAULT 0;');
      print('Upgraded database to version 2: Added isBinary column.');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE habits ADD COLUMN type INTEGER NOT NULL DEFAULT 1;');
      await db.execute('UPDATE habits SET type = 0 WHERE isBinary = 1;');
      await db.execute('UPDATE habits SET type = 1 WHERE isBinary = 0;');
      await db.execute('ALTER TABLE habits RENAME COLUMN isBinary TO isBinaryOld;');
      print('Upgraded database to version 3: Migrated isBinary to new type column.');
    }
  }

  // Optional: Function to close the database when the user signs out
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
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

  // --- CRUD Operations for Notes ---

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

  // --- Firestore Integration ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _currentUserId {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('User is not authenticated. Cannot perform Firestore operations.');
    }
    return userId;
  }

  Future<void> uploadAllDataToFirestore() async {
    try {
      final userId = _currentUserId;
      final habits = await getHabits();
      final batch = _firestore.batch();

      for (var habit in habits) {
        final habitDocRef = _firestore.collection('users').doc(userId).collection('habits').doc(habit.id.toString());
        batch.set(habitDocRef, habit.toMap());

        final completions = await getHabitCompletionsForHabit(habit.id!);
        for (var completion in completions) {
          final completionDocRef = habitDocRef.collection('completions').doc(completion.id.toString());
          batch.set(completionDocRef, completion.toMap());
        }
      }

      final notes = await getNotes();
      for (var note in notes) {
        final noteDocRef = _firestore.collection('users').doc(userId).collection('notes').doc(note.id.toString());
        batch.set(noteDocRef, note.toMap());
      }

      await batch.commit();
      print('All data uploaded to Firestore successfully!');
    } catch (e) {
      print('Error uploading data to Firestore: $e');
      rethrow;
    }
  }

  Future<void> syncDataFromFirestore() async {
    try {
      final userId = _currentUserId;
      final db = await instance.database;
      final batch = db.batch();

      final habitsSnapshot = await _firestore.collection('users').doc(userId).collection('habits').get();
      for (var doc in habitsSnapshot.docs) {
        final habit = Habit.fromMap(doc.data());
        batch.insert('habits', habit.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

        final completionsSnapshot = await doc.reference.collection('completions').get();
        for (var compDoc in completionsSnapshot.docs) {
          final completion = HabitCompletion.fromMap(compDoc.data());
          batch.insert('habit_completions', completion.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      final notesSnapshot = await _firestore.collection('users').doc(userId).collection('notes').get();
      for (var doc in notesSnapshot.docs) {
        final note = Note.fromMap(doc.data());
        batch.insert('notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit();
      print('Data synced from Firestore to Sqflite successfully!');
    } catch (e) {
      print('Error syncing data from Firestore: $e');
      rethrow;
    }
  }

  Future<void> deleteAllUserDataFromFirestore() async {
    try {
      final userId = _currentUserId;
      final batch = _firestore.batch();

      final habitsSnapshot = await _firestore.collection('users').doc(userId).collection('habits').get();
      for (var habitDoc in habitsSnapshot.docs) {
        final completionsSnapshot = await habitDoc.reference.collection('completions').get();
        for (var completionDoc in completionsSnapshot.docs) {
          batch.delete(completionDoc.reference);
        }
        batch.delete(habitDoc.reference);
      }

      final notesSnapshot = await _firestore.collection('users').doc(userId).collection('notes').get();
      for (var noteDoc in notesSnapshot.docs) {
        batch.delete(noteDoc.reference);
      }

      await batch.commit();
      print('All user data deleted from Firestore successfully for user: $userId');

      final db = await instance.database;
      await db.delete('habits');
      await db.delete('habit_completions');
      await db.delete('notes');
      print('All local Sqflite data cleared.');
    } catch (e) {
      print('Error deleting user data from Firestore: $e');
      rethrow;
    }
  }
  
  Future<void> clearAllLocalData() async {
    final db = await instance.database;
    await db.delete('habits');
    await db.delete('habit_completions');
    await db.delete('notes');
    print('All local Sqflite data cleared.');
  }
}