// --- HabitCompletion Model ---
// Represents a daily log for a specific habit
class HabitCompletion {
  int? id;
  int habitId; // Foreign key to the Habit
  int date; // Unix timestamp for the start of the day (e.g., midnight UTC)
  double loggedAmount; // The amount logged for this habit on this date
  bool isSuccess; // True if loggedAmount >= habit.goalAmount for that day

  HabitCompletion({
    this.id,
    required this.habitId,
    required this.date,
    required this.loggedAmount,
    required this.isSuccess,
  });

  // Convert a HabitCompletion object into a Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'date': date,
      'loggedAmount': loggedAmount,
      'isSuccess': isSuccess ? 1 : 0, // SQLite stores booleans as 0 or 1
    };
  }

  // Convert a Map (from database) into a HabitCompletion object
  factory HabitCompletion.fromMap(Map<String, dynamic> map) {
    return HabitCompletion(
      id: map['id'],
      habitId: map['habitId'],
      date: map['date'],
      loggedAmount: map['loggedAmount'] as double,
      isSuccess: map['isSuccess'] == 1, // Convert 0/1 back to bool
    );
  }

  @override
  String toString() {
    return 'HabitCompletion(id: $id, habitId: $habitId, date: $date, loggedAmount: $loggedAmount, isSuccess: $isSuccess)';
  }
}
