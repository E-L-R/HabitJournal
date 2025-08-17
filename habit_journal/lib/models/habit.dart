// --- Habit Model ---
class Habit {
  int? id;
  String name;
  String frequency; // e.g., 'daily', 'weekly'
  double goalAmount; // The target amount for the habit (e.g., 25 for 25 units)
  String unit; // The unit of the goal (e.g., 'minutes', 'liters', 'pages')
  int?
  lastChecked; // Unix timestamp for last overall interaction with the habit

  Habit({
    this.id,
    required this.name,
    required this.frequency,
    required this.goalAmount,
    required this.unit,
    this.lastChecked,
  });

  // Convert a Habit object into a Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'goalAmount': goalAmount,
      'unit': unit,
      'lastChecked': lastChecked,
    };
  }

  // Convert a Map (from database) into a Habit object
  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      name: map['name'],
      frequency: map['frequency'],
      goalAmount: map['goalAmount'] as double, // Ensure casting to double
      unit: map['unit'],
      lastChecked: map['lastChecked'],
    );
  }

  @override
  String toString() {
    return 'Habit(id: $id, name: $name, frequency: $frequency, goalAmount: $goalAmount $unit, lastChecked: $lastChecked)';
  }
}
