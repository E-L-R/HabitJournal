// --- Habit Model ---
class Habit {
  int? id;
  String name;
  String frequency; // e.g., 'daily', 'weekly'
  double? goalAmount; // Made nullable for binary habits
  String? unit; // Made nullable for binary habits
  bool isBinary; // New: true for yes/no habits, false for unit-based
  int? lastChecked;

  Habit({
    this.id,
    required this.name,
    required this.frequency,
    this.goalAmount, // No longer required
    this.unit, // No longer required
    this.isBinary = false, // Default to false (unit-based)
    this.lastChecked,
  });

  // Convert a Habit object into a Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'goalAmount': goalAmount, // Can be null
      'unit': unit, // Can be null
      'isBinary': isBinary ? 1 : 0, // SQLite stores booleans as 0 or 1
      'lastChecked': lastChecked,
    };
  }

  // Convert a Map (from database) into a Habit object
  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      name: map['name'],
      frequency: map['frequency'],
      goalAmount: map['goalAmount'] as double?, // Use 'as double?' for null-safe casting
      unit: map['unit'],
      isBinary: map['isBinary'] == 1, // Convert 0/1 back to bool
      lastChecked: map['lastChecked'],
    );
  }

  @override
  String toString() {
    return 'Habit(id: $id, name: $name, frequency: $frequency, isBinary: $isBinary, goalAmount: $goalAmount $unit, lastChecked: $lastChecked)';
  }
}