import 'package:flutter/material.dart';
import 'package:habit_journal/models/habit.dart';
import 'package:habit_journal/models/habit_completion.dart';
import 'package:habit_journal/services/database_service.dart';
import 'package:intl/intl.dart';

final DatabaseHelper _dbHelper = DatabaseHelper.instance;

class HabitDetailPage extends StatefulWidget {
  final Habit habit;

  const HabitDetailPage({super.key, required this.habit});

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  late Future<List<HabitCompletion>> _completionsFuture;
  List<HabitCompletion> _allCompletions = [];
  Map<int, HabitCompletion> _completionsMap = {};

  final TextEditingController _loggedAmountController = TextEditingController();

  late PageController _pageController;
  late List<DateTime> _monthsToShow;

  @override
  void initState() {
    super.initState();
    _refreshCompletions();
    _setupCalendarMonths();
    _pageController = PageController(initialPage: _monthsToShow.length - 1);
  }

  @override
  void dispose() {
    _loggedAmountController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  int _getStartOfDayTimestamp(DateTime dateTime) {
    return DateTime.utc(dateTime.year, dateTime.month, dateTime.day).millisecondsSinceEpoch;
  }

  void _refreshCompletions() {
    setState(() {
      _completionsFuture = _dbHelper.getHabitCompletionsForHabit(widget.habit.id!);
      _completionsFuture.then((completions) {
        _allCompletions = completions;
        _completionsMap = {
          for (var c in completions) c.date: c
        };
        _setupCalendarMonths();
        if (_pageController.hasClients) {
          final int currentPage = _pageController.page?.round() ?? _monthsToShow.length - 1;
          if (currentPage >= _monthsToShow.length) {
            _pageController.jumpToPage(_monthsToShow.length - 1);
          }
        }
      });
    });
  }

  void _setupCalendarMonths() {
    final DateTime now = DateTime.now();
    DateTime earliestDate = now;

    if (_allCompletions.isNotEmpty) {
      final int minTimestamp = _allCompletions.map((c) => c.date).reduce((a, b) => a < b ? a : b);
      earliestDate = DateTime.fromMillisecondsSinceEpoch(minTimestamp);
    }

    final DateTime threeMonthsAgo = DateTime.utc(now.year, now.month - 3, 1);
    final DateTime calendarStartDate = earliestDate.isBefore(threeMonthsAgo) ? earliestDate : threeMonthsAgo;

    _monthsToShow = [];
    DateTime currentMonthIterator = DateTime.utc(calendarStartDate.year, calendarStartDate.month, 1);
    while (currentMonthIterator.isBefore(DateTime.utc(now.year, now.month + 1, 1))) {
      _monthsToShow.add(currentMonthIterator);
      currentMonthIterator = DateTime.utc(currentMonthIterator.year, currentMonthIterator.month + 1, 1);
    }
  }

  void _openUnitCompletionDialog({HabitCompletion? existingCompletion, required DateTime date}) {
    final _loggedAmountController = TextEditingController(
      text: existingCompletion?.loggedAmount.toString() ?? '',
    );
    final _dateController = TextEditingController(
      text: DateFormat.yMd().format(date),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingCompletion == null ? 'Log Completion' : 'Edit Completion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _loggedAmountController,
              decoration: InputDecoration(
                labelText: 'Logged Amount (${widget.habit.unit})',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Date (MM/DD/YYYY)'),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (pickedDate != null) {
                  _dateController.text = DateFormat.yMd().format(pickedDate);
                }
              },
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
              final double? loggedAmount = double.tryParse(_loggedAmountController.text);
              if (loggedAmount == null) {
                return;
              }
              final selectedDate = DateFormat.yMd().parse(_dateController.text);

              if (existingCompletion != null) {
                existingCompletion.loggedAmount = loggedAmount;
                existingCompletion.date = selectedDate.millisecondsSinceEpoch;
                await _dbHelper.updateHabitCompletion(existingCompletion);
              } else {
                await _dbHelper.logHabitCompletion(
                  habitId: widget.habit.id!,
                  loggedAmount: loggedAmount,
                  date: selectedDate,
                );
              }
              _refreshCompletions();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleBinaryCompletion({HabitCompletion? existingCompletion, required DateTime date}) async {
    final int dateTimestamp = _getStartOfDayTimestamp(date);
    HabitCompletion? completionForDate = existingCompletion ?? await _dbHelper.getHabitCompletionForDate(widget.habit.id!, date);
    
    if (completionForDate != null) {
      // Toggle off by deleting the completion
      await _dbHelper.deleteHabitCompletion(completionForDate.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Completion for ${DateFormat.yMd().format(date)} deleted.')),
      );
    } else {
      // Toggle on by logging a new completion
      await _dbHelper.logHabitCompletion(
        habitId: widget.habit.id!,
        loggedAmount: 1.0,
        date: date,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Habit completed for ${DateFormat.yMd().format(date)}!')),
      );
    }
    _refreshCompletions();
  }

  int _getTotalAttemptedDays() {
    return _allCompletions.where((c) => c.loggedAmount > 0).length;
  }

  int _getTotalCompletedDays() {
    return _allCompletions.where((c) => c.isSuccess).length;
  }

  double _getAverageCompletion() {
    final attemptedCompletions = _allCompletions.where((c) => c.loggedAmount > 0).toList();
    if (attemptedCompletions.isEmpty) {
      return 0.0;
    }
    final totalLoggedAmount = attemptedCompletions.fold(0.0, (sum, c) => sum + c.loggedAmount);
    return totalLoggedAmount / attemptedCompletions.length;
  }

  int _getCurrentStreak() {
    if (_allCompletions.isEmpty) return 0;
    final sortedCompletions = List<HabitCompletion>.from(_allCompletions)
      ..sort((a, b) => a.date.compareTo(b.date));
    int currentStreak = 0;
    final todayStartOfDay = _getStartOfDayTimestamp(DateTime.now());
    final todayCompletion = sortedCompletions.firstWhereOrNull((c) => c.date == todayStartOfDay);
    if (todayCompletion == null || !todayCompletion.isSuccess) {
      return 0;
    }
    currentStreak = 1;
    DateTime lastDate = DateTime.fromMillisecondsSinceEpoch(todayCompletion.date);
    for (int i = sortedCompletions.length - 2; i >= 0; i--) {
      final completion = sortedCompletions[i];
      final completionDate = DateTime.fromMillisecondsSinceEpoch(completion.date);
      if (completion.isSuccess && _getStartOfDayTimestamp(completionDate.add(const Duration(days: 1))) == _getStartOfDayTimestamp(lastDate)) {
        currentStreak++;
        lastDate = completionDate;
      } else if (_getStartOfDayTimestamp(completionDate) != _getStartOfDayTimestamp(lastDate.subtract(const Duration(days: 1)))) {
        break;
      }
    }
    return currentStreak;
  }

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
            _getStartOfDayTimestamp(completionDate) == _getStartOfDayTimestamp(lastSuccessfulDate.add(const Duration(days: 1)))) {
          currentStreak++;
        } else if (_getStartOfDayTimestamp(completionDate) != _getStartOfDayTimestamp(lastSuccessfulDate)) {
          currentStreak = 1;
        }
        lastSuccessfulDate = completionDate;
      } else {
        currentStreak = 0;
      }
      longestStreak = currentStreak > longestStreak ? currentStreak : longestStreak;
    }
    return longestStreak;
  }

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
        title: Text(widget.habit.name),
      ),
      body: FutureBuilder<List<HabitCompletion>>(
        future: _completionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.habit.isBinary)
                    const Text('Type: Yes/No', style: TextStyle(fontSize: 18))
                  else
                    Text(
                      'Goal: ${widget.habit.goalAmount?.toStringAsFixed(0)} ${widget.habit.unit}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  const SizedBox(height: 16.0),
                  const Divider(),
                  _buildCalendar(),
                  const SizedBox(height: 24.0),
                  const Divider(),
                  _buildStatistics(),
                ],
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final today = DateTime.now();
          if (widget.habit.isBinary) {
            _handleBinaryCompletion(date: today);
          } else {
            _openUnitCompletionDialog(date: today);
          }
        },
        child: widget.habit.isBinary ? const Icon(Icons.check) : const Icon(Icons.add),
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
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _monthsToShow.length,
            itemBuilder: (context, monthIndex) {
              final DateTime month = _monthsToShow[monthIndex];
              final String monthName = DateFormat('MMMM yyyy').format(month);
              final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
              List<DateTime> monthDates = List.generate(daysInMonth, (index) => DateTime.utc(month.year, month.month, index + 1));
              final int firstDayWeekday = monthDates.first.weekday;
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) {
                      final weekday = DateFormat('EE').format(DateTime(2023, 1, 2 + index));
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
                  Expanded(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        crossAxisSpacing: 4.0,
                        mainAxisSpacing: 4.0,
                      ),
                      itemCount: daysInMonth + (firstDayWeekday - 1),
                      itemBuilder: (context, index) {
                        if (index < firstDayWeekday - 1) {
                          return Container();
                        }
                        final date = monthDates[index - (firstDayWeekday - 1)];
                        final startOfDayTimestamp = _getStartOfDayTimestamp(date);
                        final completion = _completionsMap[startOfDayTimestamp];
                        Color indicatorColor;
                        Widget indicatorContent;
                        if (completion != null) {
                          indicatorColor = completion.isSuccess ? Colors.green.shade600 : Colors.red.shade600;
                          if (widget.habit.isBinary) {
                            indicatorContent = Icon(completion.isSuccess ? Icons.check : Icons.close, color: Colors.white, size: 20);
                          } else {
                            indicatorContent = Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('d').format(date),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  completion.loggedAmount.toStringAsFixed(0),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            );
                          }
                        } else {
                          indicatorColor = Colors.grey.shade200;
                          indicatorContent = Text(
                            DateFormat('d').format(date),
                            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.normal, fontSize: 14),
                          );
                        }

                        bool isToday = _getStartOfDayTimestamp(date) == _getStartOfDayTimestamp(DateTime.now());

                        return GestureDetector(
                          onTap: () {
                            if (widget.habit.isBinary) {
                              _handleBinaryCompletion(existingCompletion: completion, date: date);
                            } else {
                              _openUnitCompletionDialog(existingCompletion: completion, date: date);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: indicatorColor,
                              borderRadius: BorderRadius.circular(8.0),
                              border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : Border.all(color: Colors.black12, width: 1),
                            ),
                            child: Center(child: indicatorContent),
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
        if (!widget.habit.isBinary)
          _buildStatRow('Average Completion:', '${averageCompletion.toStringAsFixed(1)} ${widget.habit.unit}'),
        _buildStatRow('Success Rate:', '${successRate.toStringAsFixed(1)}%'),
        _buildStatRow('Current Streak:', '$currentStreak days'),
        _buildStatRow('Longest Streak:', '$longestStreak days'),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}