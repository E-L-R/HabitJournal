import 'package:flutter/material.dart';
import 'package:habit_journal/models/habit.dart';
import 'package:habit_journal/models/habit_completion.dart';
import 'package:intl/intl.dart';
import 'package:habit_journal/services/database_service.dart'; // Ensure DatabaseHelper path is correct
import 'package:habit_journal/habit_detail_page.dart'; // Import the new detail page

// Database helper instance
final DatabaseHelper dbHelper = DatabaseHelper.instance;

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  // A future to hold habits, to be used with FutureBuilder
  late Future<List<Habit>> _habitsFuture;

  // Text editing controllers for habit dialog
  final TextEditingController _habitNameController = TextEditingController();
  final TextEditingController _goalAmountController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshHabits(); // Load habits when the widget initializes
  }

  @override
  void dispose() {
    _habitNameController.dispose();
    _goalAmountController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  // Method to refresh the list of habits
  void _refreshHabits() {
    setState(() {
      _habitsFuture = dbHelper.getHabits();
    });
  }

  // Helper to get the start of the day in UTC milliseconds
  int _getStartOfDayTimestamp(DateTime dateTime) {
    return DateTime.utc(dateTime.year, dateTime.month, dateTime.day).millisecondsSinceEpoch;
  }

  // --- Habit Management Dialogs ---

  // Open a dialog box to add/edit a habit
  void _openHabitDialog({Habit? existingHabit}) {
    if (existingHabit != null) {
      _habitNameController.text = existingHabit.name;
      _goalAmountController.text = existingHabit.goalAmount.toString();
      _unitController.text = existingHabit.unit;
    } else {
      _habitNameController.clear();
      _goalAmountController.clear();
      _unitController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingHabit == null ? 'Add New Habit' : 'Edit Habit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _habitNameController,
                decoration: const InputDecoration(labelText: 'Habit Name'),
              ),
              TextField(
                controller: _goalAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Daily Goal Amount'),
              ),
              TextField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Unit (e.g., "liters", "pages")'),
              ),
              // You might add frequency selection here, but for simplicity, we'll keep it static for now
              // For 'frequency', we'll hardcode 'daily' or add a default.
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
                  _goalAmountController.text.isEmpty ||
                  _unitController.text.isEmpty) {
                // Basic validation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              final String name = _habitNameController.text;
              final double goalAmount = double.tryParse(_goalAmountController.text) ?? 0.0;
              final String unit = _unitController.text;

              if (existingHabit == null) {
                // Add new habit
                final newHabit = Habit(
                  name: name,
                  frequency: 'daily', // Defaulting to daily for now
                  goalAmount: goalAmount,
                  unit: unit,
                  lastChecked: DateTime.now().millisecondsSinceEpoch,
                );
                await dbHelper.insertHabit(newHabit);
              } else {
                // Update existing habit
                existingHabit.name = name;
                existingHabit.goalAmount = goalAmount;
                existingHabit.unit = unit;
                await dbHelper.updateHabit(existingHabit);
              }
              _refreshHabits();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      _habitNameController.clear();
      _goalAmountController.clear();
      _unitController.clear();
    });
  }

  // Show confirmation dialog for habit deletion
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

  // --- Habit Completion Logging Dialog ---

  // Open dialog to log completion for a specific day
  void _openLogCompletionDialog(Habit habit, DateTime date) async {
    final int dateTimestamp = _getStartOfDayTimestamp(date);
    HabitCompletion? existingCompletion = await dbHelper.getHabitCompletionForDate(habit.id!, date);

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
              _refreshHabits(); // Refresh to update the success/failure indicators
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- Widget Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text('Habit Tracker'),
        automaticallyImplyLeading: false, // You might want to remove this if you have a drawer
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
                return GestureDetector( // Added GestureDetector for navigation
                  onTap: () async {
                    // Navigate to the detail page and await for it to pop
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HabitDetailPage(habit: habit),
                      ),
                    );
                    _refreshHabits(); // Refresh habits on this page when returning from detail page
                  },
                  child: _buildHabitCard(habit),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openHabitDialog(),
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
                    // Stop tap propagation to avoid navigating when editing
                    _openHabitDialog(existingHabit: habit);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    // Stop tap propagation to avoid navigating when deleting
                    _confirmDeleteHabit(habit.id!);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              'Goal: ${habit.goalAmount.toStringAsFixed(0)} ${habit.unit} daily',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
            ),
            const Divider(height: 20, thickness: 1),
            // Display the last 7 days for logging
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
                  // Map completions by date for efficient lookup
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
                      String indicatorText;

                      if (completion != null) {
                        indicatorColor = completion.isSuccess ? Colors.green.shade600 : Colors.red.shade600;
                        indicatorText = completion.loggedAmount.toStringAsFixed(0); // Display logged amount
                      } else {
                        indicatorColor = Colors.grey.shade300;
                        indicatorText = 'N/A'; // No completion logged
                      }

                      return GestureDetector(
                        onTap: () {
                          // Allow logging from the main page too, but don't navigate
                          _openLogCompletionDialog(habit, date);
                        },
                        child: Column(
                          children: [
                            Text(
                              DateFormat('EEE').format(date), // Mon, Tue etc.
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              DateFormat('MMM d').format(date), // Aug 17, etc.
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
                                child: Text(
                                  indicatorText,
                                  style: TextStyle(
                                    color: (completion != null && completion.isSuccess) ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
