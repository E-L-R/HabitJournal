import 'package:flutter/material.dart';
import 'package:habit_journal/models/habit.dart';
import 'package:habit_journal/models/habit_completion.dart';
import 'package:intl/intl.dart';
import 'package:habit_journal/services/database_service.dart';
import 'package:habit_journal/habit_detail_page.dart';
import 'package:habit_journal/create_habit_page.dart';

final DatabaseHelper dbHelper = DatabaseHelper.instance;

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  late Future<List<Habit>> _habitsFuture;

  @override
  void initState() {
    super.initState();
    _refreshHabits();
  }

  void _refreshHabits() {
    setState(() {
      _habitsFuture = dbHelper.getHabits();
    });
  }

  int _getStartOfDayTimestamp(DateTime dateTime) {
    return DateTime.utc(dateTime.year, dateTime.month, dateTime.day).millisecondsSinceEpoch;
  }

  void _confirmDeleteHabit(int habitId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Habit'),
        content: const Text('Are you sure you want to delete this habit and all its logged completions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await dbHelper.deleteHabit(habitId);
              _refreshHabits();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Updated to handle both unit and time-based habits
  void _openLogCompletionDialog(Habit habit, DateTime date) async {
    final int dateTimestamp = _getStartOfDayTimestamp(date);
    HabitCompletion? existingCompletion = await dbHelper.getHabitCompletionForDate(habit.id!, date);

    if (habit.type == HabitType.binary) {
      final bool newCompletionStatus = !(existingCompletion?.isSuccess ?? false);
      await dbHelper.logHabitCompletion(
        habitId: habit.id!,
        loggedAmount: newCompletionStatus ? 1.0 : 0.0,
        date: date,
      );
      _refreshHabits();
    } else {
      final TextEditingController loggedAmountController = TextEditingController();
      if (existingCompletion != null) {
        loggedAmountController.text = existingCompletion.loggedAmount.toString();
      }

      String unitLabel = habit.unit ?? 'units';
      if (habit.type == HabitType.time) {
        unitLabel = 'minutes';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Log ${habit.name} for ${DateFormat.yMMMd().format(date)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Goal: ${habit.goalAmount} ${habit.unit}'),
              TextField(
                controller: loggedAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Logged Amount ($unitLabel)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final double loggedAmount = double.tryParse(loggedAmountController.text) ?? 0.0;
                await dbHelper.logHabitCompletion(
                  habitId: habit.id!,
                  loggedAmount: loggedAmount,
                  date: date,
                );
                _refreshHabits();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text('Habit Tracker'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<Habit>>(
        future: _habitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No habits yet. Tap the + button to add one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          } else {
            List<Habit> habits = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: habits.length,
              itemBuilder: (context, index) {
                final habit = habits[index];
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HabitDetailPage(habit: habit),
                      ),
                    );
                    _refreshHabits();
                  },
                  child: _buildHabitCard(habit),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateHabitPage()),
          );
          if (result == true) {
            _refreshHabits();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHabitCard(Habit habit) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  FutureBuilder<HabitCompletion?>(
                    future: dbHelper.getHabitCompletionForDate(habit.id!, DateTime.now()),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text('Loading...');
                      }
                      final completion = snapshot.data;
                      final isCompleted = completion?.isSuccess ?? false;
                      String completionText = 'Not completed today';
                      Color textColor = Colors.red;

                      if (isCompleted) {
                        textColor = Colors.green;
                        if (habit.type == HabitType.binary) {
                          completionText = 'Completed today!';
                        } else {
                          completionText = 'Completed: ${completion!.loggedAmount.toStringAsFixed(0)} ${habit.unit}';
                        }
                      } else if (habit.type == HabitType.time) {
                        // Display the goal for time-based habits
                        completionText = 'Goal: ${habit.goalAmount?.toStringAsFixed(0)} ${habit.unit}';
                        textColor = Colors.black54;
                      } else if (habit.type == HabitType.unit) {
                        // Display the goal for unit-based habits
                        completionText = 'Goal: ${habit.goalAmount?.toStringAsFixed(0)} ${habit.unit}';
                        textColor = Colors.black54;
                      }

                      return Text(
                        completionText,
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                habit.type == HabitType.binary
                    ? Icons.check_circle_outline
                    : habit.type == HabitType.unit
                        ? Icons.add_circle_outline
                        : Icons.timer,
                color: Colors.blueAccent,
                size: 30,
              ),
              onPressed: () => _openLogCompletionDialog(habit, DateTime.now()),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.grey, size: 24),
              onPressed: () => _confirmDeleteHabit(habit.id!),
            ),
          ],
        ),
      ),
    );
  }
}