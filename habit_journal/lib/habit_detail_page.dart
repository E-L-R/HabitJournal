import 'package:flutter/material.dart';
import 'package:habit_journal/habits_page.dart';
import 'package:habit_journal/models/habit.dart';
import 'package:habit_journal/models/habit_completion.dart';
import 'package:intl/intl.dart';

class HabitDetailPage extends StatefulWidget {
  final Habit habit;

  const HabitDetailPage({super.key, required this.habit});

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  late Future<List<HabitCompletion>> _completionsFuture;
  List<HabitCompletion> _allCompletions = []; // Initialize to empty list
  Map<int, HabitCompletion> _completionsMap = {}; // Initialize to empty map

  // Controllers for logging dialog (reused from HabitTrackerPage)
  final TextEditingController _loggedAmountController = TextEditingController();

  late PageController _pageController;
  late List<DateTime> _monthsToShow; // List of first day of each month to display

  @override
  void initState() {
    super.initState();
    _refreshCompletions(); // This will populate _allCompletions and _completionsMap
    _setupCalendarMonths(); // Depends on _allCompletions being initialized
    // Set initial page to the current month
    _pageController = PageController(initialPage: _monthsToShow.length - 1);
  }

  @override
  void dispose() {
    _loggedAmountController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Helper to get the start of the day in UTC milliseconds
  int _getStartOfDayTimestamp(DateTime dateTime) {
    return DateTime.utc(dateTime.year, dateTime.month, dateTime.day).millisecondsSinceEpoch;
  }

  // Refresh completions and rebuild map
  void _refreshCompletions() {
    setState(() {
      _completionsFuture = dbHelper.getHabitCompletionsForHabit(widget.habit.id!);
      _completionsFuture.then((completions) {
        _allCompletions = completions;
        _completionsMap = {
          for (var c in completions) c.date: c
        };
        // Re-setup months in case new completions extend the history
        _setupCalendarMonths();
        // If a new month is added, adjust page controller to stay on relevant month
        if (_pageController.hasClients) {
          final int currentPage = _pageController.page?.round() ?? _monthsToShow.length - 1;
          if (currentPage >= _monthsToShow.length) {
            _pageController.jumpToPage(_monthsToShow.length - 1);
          }
        }
      });
    });
  }

  // Determine the months to show in the calendar
  void _setupCalendarMonths() {
    final DateTime now = DateTime.now();
    DateTime earliestDate = now;

    if (_allCompletions.isNotEmpty) {
      // Find the earliest completion date
      final int minTimestamp = _allCompletions.map((c) => c.date).reduce((a, b) => a < b ? a : b);
      earliestDate = DateTime.fromMillisecondsSinceEpoch(minTimestamp);
    }

    // Go back at least 3 months, or to the earliest habit completion, whichever is earlier
    final DateTime threeMonthsAgo = DateTime.utc(now.year, now.month - 3, 1);
    final DateTime calendarStartDate = earliestDate.isBefore(threeMonthsAgo) ? earliestDate : threeMonthsAgo;

    _monthsToShow = [];
    DateTime currentMonthIterator = DateTime.utc(calendarStartDate.year, calendarStartDate.month, 1);
    while (currentMonthIterator.isBefore(DateTime.utc(now.year, now.month + 1, 1))) {
      _monthsToShow.add(currentMonthIterator);
      currentMonthIterator = DateTime.utc(currentMonthIterator.year, currentMonthIterator.month + 1, 1);
    }
  }

  // Open dialog to log completion for a specific day (reused from HabitTrackerPage)
  void _openLogCompletionDialog(DateTime date) async {
    final int dateTimestamp = _getStartOfDayTimestamp(date);
    HabitCompletion? existingCompletion = _completionsMap[dateTimestamp];

    if (existingCompletion != null) {
      _loggedAmountController.text = existingCompletion.loggedAmount.toString();
    } else {
      _loggedAmountController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log ${widget.habit.name} for ${DateFormat.yMMMd().format(date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Goal: ${widget.habit.goalAmount} ${widget.habit.unit}'),
            TextField(
              controller: _loggedAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Logged Amount (${widget.habit.unit})',
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
              final double loggedAmount = double.tryParse(_loggedAmountController.text) ?? 0.0;
              await dbHelper.logHabitCompletion(
                habitId: widget.habit.id!,
                loggedAmount: loggedAmount,
                date: date,
              );
              _refreshCompletions(); // Refresh to update the calendar and stats
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- Statistics Calculation Methods ---

  // Calculate total days attempted (loggedAmount > 0)
  int _getTotalAttemptedDays() {
    return _allCompletions.where((c) => c.loggedAmount > 0).length;
  }

  // Calculate total completed days (isSuccess == true)
  int _getTotalCompletedDays() {
    return _allCompletions.where((c) => c.isSuccess).length;
  }

  // Calculate average completion for attempted days
  double _getAverageCompletion() {
    final attemptedCompletions = _allCompletions.where((c) => c.loggedAmount > 0).toList();
    if (attemptedCompletions.isEmpty) {
      return 0.0;
    }
    final totalLoggedAmount = attemptedCompletions.fold(0.0, (sum, c) => sum + c.loggedAmount);
    return totalLoggedAmount / attemptedCompletions.length;
  }

  // Calculate current streak length
  int _getCurrentStreak() {
    if (_allCompletions.isEmpty) return 0;

    // Sort completions by date ascending
    final sortedCompletions = List<HabitCompletion>.from(_allCompletions)
      ..sort((a, b) => a.date.compareTo(b.date));

    int currentStreak = 0;
    
    // Get today's start timestamp
    final todayStartOfDay = _getStartOfDayTimestamp(DateTime.now());

    // Check if today was successful. If not, streak is 0.
    final todayCompletion = sortedCompletions.firstWhereOrNull(
        (c) => c.date == todayStartOfDay);

    if (todayCompletion == null || !todayCompletion.isSuccess) {
      return 0;
    }

    currentStreak = 1;
    DateTime lastDate = DateTime.fromMillisecondsSinceEpoch(todayCompletion.date);

    for (int i = sortedCompletions.length - 2; i >= 0; i--) {
      final completion = sortedCompletions[i];
      final completionDate = DateTime.fromMillisecondsSinceEpoch(completion.date);

      // Check if the current completion is for the day immediately preceding the last successful day
      // and that it's also a successful completion
      if (completion.isSuccess && _getStartOfDayTimestamp(completionDate.add(const Duration(days: 1))) == _getStartOfDayTimestamp(lastDate)) {
        currentStreak++;
        lastDate = completionDate;
      } else if (_getStartOfDayTimestamp(completionDate) != _getStartOfDayTimestamp(lastDate.subtract(const Duration(days: 1)))) {
        // If there's a gap (not consecutive) or a non-success, break the streak
        break;
      }
    }
    return currentStreak;
  }

  // Calculate longest streak length
  int _getLongestStreak() {
    if (_allCompletions.isEmpty) return 0;

    final sortedCompletions = List<HabitCompletion>.from(_allCompletions)
      ..sort((a, b) => a.date.compareTo(b.date));

    int longestStreak = 0;
    int currentStreak = 0;
    DateTime? lastSuccessfulDate;

    for (int i = 0; i < sortedCompletions.length; i++) {
      final completion = sortedCompletions[i];
      final completionDate = DateTime.fromMillisecondsSinceEpoch(completion.date);

      if (completion.isSuccess) {
        if (lastSuccessfulDate == null ||
            _getStartOfDayTimestamp(completionDate) == _getStartOfDayTimestamp(lastSuccessfulDate!.add(const Duration(days: 1)))) {
          currentStreak++;
        } else if (_getStartOfDayTimestamp(completionDate) != _getStartOfDayTimestamp(lastSuccessfulDate!)) {
          // If there's a gap or a date jump (not consecutive), reset streak
          currentStreak = 1;
        }
        lastSuccessfulDate = completionDate;
      } else {
        // Reset streak if not successful
        currentStreak = 0;
      }
      longestStreak = currentStreak > longestStreak ? currentStreak : longestStreak;
    }
    return longestStreak;
  }

  // Calculate success rate
  double _getSuccessRate() {
    final totalAttempted = _getTotalAttemptedDays();
    final totalCompleted = _getTotalCompletedDays();
    if (totalAttempted == 0) return 0.0;
    return (totalCompleted / totalAttempted) * 100;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text('${widget.habit.name} Details'),
      ),
      body: FutureBuilder<List<HabitCompletion>>(
        future: _completionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            // Data is available, build the page
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Goal: ${widget.habit.goalAmount.toStringAsFixed(0)} ${widget.habit.unit} daily',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16.0),
                  const Divider(),
                  // --- Calendar View ---
                  _buildCalendar(),
                  const SizedBox(height: 24.0),
                  const Divider(),
                  // --- Statistics ---
                  _buildStatistics(),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completion History',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        SizedBox(
          height: 300, // Fixed height for the calendar grid + month header
          child: PageView.builder(
            controller: _pageController,
            itemCount: _monthsToShow.length,
            itemBuilder: (context, monthIndex) {
              final DateTime month = _monthsToShow[monthIndex];
              final String monthName = DateFormat('MMMM yyyy').format(month);

              // Calculate all days in the current month
              final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
              List<DateTime> monthDates = List.generate(daysInMonth, (index) =>
                  DateTime.utc(month.year, month.month, index + 1));

              // Determine the first day of the week for the first day of the month
              // This is to pad the beginning of the month's grid
              final int firstDayWeekday = monthDates.first.weekday; // Monday is 1, Sunday is 7

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      monthName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Weekday headers (Mon, Tue, Wed...)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) {
                      final weekday = DateFormat('EE').format(DateTime(2023, 1, 2 + index)); // Start from Monday
                      return Expanded(
                        child: Center(
                          child: Text(
                            weekday,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4.0),
                  Expanded( // Use Expanded to allow GridView to fill remaining space
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7, // 7 days a week
                        crossAxisSpacing: 4.0,
                        mainAxisSpacing: 4.0,
                      ),
                      itemCount: daysInMonth + (firstDayWeekday - 1), // Add leading blank spaces
                      itemBuilder: (context, index) {
                        if (index < firstDayWeekday - 1) {
                          return Container(); // Empty container for padding
                        }
                        final date = monthDates[index - (firstDayWeekday - 1)];
                        final startOfDayTimestamp = _getStartOfDayTimestamp(date);
                        final completion = _completionsMap[startOfDayTimestamp];

                        Color indicatorColor;
                        String indicatorText;

                        if (completion != null) {
                          indicatorColor = completion.isSuccess ? Colors.green.shade600 : Colors.red.shade600;
                          indicatorText = completion.loggedAmount.toStringAsFixed(0);
                        } else {
                          indicatorColor = Colors.grey.shade200;
                          indicatorText = ''; // No completion logged
                        }

                        bool isToday = _getStartOfDayTimestamp(date) == _getStartOfDayTimestamp(DateTime.now());

                        return GestureDetector(
                          onTap: () => _openLogCompletionDialog(date),
                          child: Container(
                            decoration: BoxDecoration(
                              color: indicatorColor,
                              borderRadius: BorderRadius.circular(8.0),
                              border: isToday
                                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                  : Border.all(color: Colors.black12, width: 1),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('d').format(date), // Day of month
                                  style: TextStyle(
                                    color: (completion != null && completion.isSuccess) ? Colors.white : Colors.black87,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                if (indicatorText.isNotEmpty)
                                  Text(
                                    indicatorText,
                                    style: TextStyle(
                                      color: (completion != null && completion.isSuccess) ? Colors.white70 : Colors.black54,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    final totalAttemptedDays = _getTotalAttemptedDays();
    final totalCompletedDays = _getTotalCompletedDays();
    final averageCompletion = _getAverageCompletion();
    final currentStreak = _getCurrentStreak();
    final longestStreak = _getLongestStreak();
    final successRate = _getSuccessRate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        _buildStatRow('Total Days Attempted:', '$totalAttemptedDays days'),
        _buildStatRow('Total Completed Days:', '$totalCompletedDays days'),
        _buildStatRow('Average Completion:', '${averageCompletion.toStringAsFixed(1)} ${widget.habit.unit}'),
        _buildStatRow('Success Rate:', '${successRate.toStringAsFixed(1)}%'),
        _buildStatRow('Current Streak:', '$currentStreak days'),
        _buildStatRow('Longest Streak:', '$longestStreak days'),
        // Add more statistics here if desired
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// Extension to help with finding element in list (similar to what `firstWhereOrNull` would do)
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
