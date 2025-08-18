// lib/models/habit.dart
enum HabitType { binary, unit, time }

// --- Habit Model ---
class Habit {
  int? id;
  String name;
  String frequency; // e.g., 'daily', 'weekly'
  double? goalAmount; // The target amount or duration
  String? unit; // The unit of the goal (e.g., 'minutes', 'liters')
  HabitType type; // New: The type of habit (binary, unit, or time)
  int? lastChecked; // Unix timestamp for last overall interaction with the habit

  Habit({
    this.id,
    required this.name,
    required this.frequency,
    this.goalAmount,
    this.unit,
    this.lastChecked,
    this.type = HabitType.unit, // New: Default to unit-based
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'goalAmount': goalAmount,
      'unit': unit,
      'type': type.index, // New: Store the enum index
      'lastChecked': lastChecked,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      name: map['name'],
      frequency: map['frequency'],
      goalAmount: map['goalAmount'] as double?, // Made nullable
      unit: map['unit'],
      type: HabitType.values[map['type'] as int], // New: Get enum from index
      lastChecked: map['lastChecked'],
    );
  }

  @override
  String toString() {
    return 'Habit{id: $id, name: $name, type: ${type.name}, goalAmount: $goalAmount, unit: $unit}';
  }
}

// --- HabitCompletion Model (No changes needed) ---
// ... keep this file as is