import 'package:flutter/material.dart';
import 'package:habit_journal/create_habit_page.dart';
import 'package:habit_journal/models/habit.dart';
import 'package:habit_journal/models/habit_completion.dart';
import 'package:intl/intl.dart';
import 'package:habit_journal/services/database_service.dart';
import 'package:habit_journal/habit_detail_page.dart';

final DatabaseHelper dbHelper = DatabaseHelper.instance;

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  late Future<List<Habit>> _habitsFuture;

  // Controllers for habit dialog
  final TextEditingController _habitNameController = TextEditingController();
  final TextEditingController _goalAmountController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  // State variable for the habit type
  bool _isBinaryHabit = false;

  @override
  void initState() {
    super.initState();
    _refreshHabits();
  }

  @override
  void dispose() {
    _habitNameController.dispose();
    _goalAmountController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _refreshHabits() {
    setState(() {
      _habitsFuture = dbHelper.getHabits();
    });
  }

  int _getStartOfDayTimestamp(DateTime dateTime) {
    return DateTime.utc(dateTime.year, dateTime.month, dateTime.day).millisecondsSinceEpoch;
  }

  // --- Habit Management Dialogs ---

  void _openHabitDialog({Habit? existingHabit}) {
    if (existingHabit != null) {
      _habitNameController.text = existingHabit.name;
      _isBinaryHabit = existingHabit.isBinary; // Set the state based on existing habit
      if (!existingHabit.isBinary) {
        _goalAmountController.text = existingHabit.goalAmount?.toString() ?? '';
        _unitController.text = existingHabit.unit ?? '';
      } else {
        _goalAmountController.clear();
        _unitController.clear();
      }
    } else {
      _habitNameController.clear();
      _goalAmountController.clear();
      _unitController.clear();
      _isBinaryHabit = false; // Default to unit-based for new habits
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Use StatefulBuilder to update the dialog's state
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(existingHabit == null ? 'Add New Habit' : 'Edit Habit'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _habitNameController,
                    decoration: const InputDecoration(labelText: 'Habit Name'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Habit Type:'),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _isBinaryHabit = false),
                        icon: const Icon(Icons.numbers),
                        label: const Text('Unit-Based'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: _isBinaryHabit ? null : Colors.white,
                          backgroundColor: _isBinaryHabit ? null : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _isBinaryHabit = true),
                        icon: const Icon(Icons.check),
                        label: const Text('Yes/No'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: !_isBinaryHabit ? null : Colors.white,
                          backgroundColor: !_isBinaryHabit ? null : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (!_isBinaryHabit) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _goalAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Daily Goal Amount'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Unit (e.g., "liters", "pages")'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_habitNameController.text.isEmpty ||
                      (!_isBinaryHabit && (_goalAmountController.text.isEmpty || _unitController.text.isEmpty))) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }

                  final String name = _habitNameController.text;
                  final double? goalAmount = _isBinaryHabit ? null : double.tryParse(_goalAmountController.text);
                  final String? unit = _isBinaryHabit ? null : _unitController.text;

                  if (existingHabit == null) {
                    final newHabit = Habit(
                      name: name,
                      frequency: 'daily',
                      goalAmount: goalAmount,
                      unit: unit,
                      isBinary: _isBinaryHabit,
                      lastChecked: DateTime.now().millisecondsSinceEpoch,
                    );
                    await dbHelper.insertHabit(newHabit);
                  } else {
                    existingHabit.name = name;
                    existingHabit.goalAmount = goalAmount;
                    existingHabit.unit = unit;
                    existingHabit.isBinary = _isBinaryHabit;
                    await dbHelper.updateHabit(existingHabit);
                  }
                  _refreshHabits();
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      // Reset state after dialog closes
      _isBinaryHabit = false;
    });
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

  void _openLogCompletionDialog(Habit habit, DateTime date) async {
    final int dateTimestamp = _getStartOfDayTimestamp(date);
    HabitCompletion? existingCompletion = await dbHelper.getHabitCompletionForDate(habit.id!, date);

    // For binary habits, a simple checkmark or toggle is better
    if (habit.isBinary) {
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
                  labelText: 'Logged Amount (${habit.unit})',
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

  // --- Widget Build Method ---

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

  // Helper method to build a single habit card
  Widget _buildHabitCard(Habit habit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 6.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    habit.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                  onPressed: () {
                    _openHabitDialog(existingHabit: habit);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    _confirmDeleteHabit(habit.id!);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            // Updated to handle both habit types
            if (!habit.isBinary)
              Text(
                'Goal: ${habit.goalAmount?.toStringAsFixed(0)} ${habit.unit} daily',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
              )
            else
              Text(
                'Type: Yes/No',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
              ),
            const Divider(height: 20, thickness: 1),
            Text(
              'Last 7 Days:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            FutureBuilder<List<HabitCompletion>>(
              future: dbHelper.getHabitCompletionsForHabit(habit.id!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Error loading completions: ${snapshot.error}');
                } else {
                  final Map<int, HabitCompletion> completionsMap = {
                    for (var c in snapshot.data!) c.date: c
                  };

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) {
                      final date = DateTime.now().subtract(Duration(days: 6 - index));
                      final startOfDayTimestamp = _getStartOfDayTimestamp(date);
                      final completion = completionsMap[startOfDayTimestamp];

                      Color indicatorColor;
                      Widget indicatorContent;

                      if (completion != null) {
                        indicatorColor = completion.isSuccess ? Colors.green.shade600 : Colors.red.shade600;
                        if (habit.isBinary) {
                          indicatorContent = Icon(completion.isSuccess ? Icons.check : Icons.close, color: Colors.white,);
                        } else {
                          indicatorContent = Text(
                            completion.loggedAmount.toStringAsFixed(0),
                            style: TextStyle(
                              color: completion.isSuccess ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                      } else {
                        indicatorColor = Colors.grey.shade300;
                        indicatorContent = Text(
                          'N/A',
                          style: TextStyle(color: Colors.black),
                        );
                      }

                      return GestureDetector(
                        onTap: () {
                          _openLogCompletionDialog(habit, date);
                        },
                        child: Column(
                          children: [
                            Text(
                              DateFormat('EEE').format(date),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              DateFormat('MMM d').format(date),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: indicatorColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Center(
                                child: indicatorContent,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}