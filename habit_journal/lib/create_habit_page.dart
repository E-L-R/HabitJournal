import 'package:flutter/material.dart';
import 'package:habit_journal/models/habit.dart';
import 'package:habit_journal/services/database_service.dart';

class CreateHabitPage extends StatefulWidget {
  const CreateHabitPage({super.key});

  @override
  State<CreateHabitPage> createState() => _CreateHabitPageState();
}

class _CreateHabitPageState extends State<CreateHabitPage> {
  final _formKey = GlobalKey<FormState>();
  final _habitNameController = TextEditingController();
  final _goalAmountController = TextEditingController();
  final _unitController = TextEditingController();

  HabitType _selectedType = HabitType.binary;

  @override
  void dispose() {
    _habitNameController.dispose();
    _goalAmountController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _saveHabit() async {
    if (_formKey.currentState!.validate()) {
      final name = _habitNameController.text;
      final goalAmount = (_selectedType == HabitType.binary) ? null : double.tryParse(_goalAmountController.text);
      
      // Conditionally set the unit based on the habit type
      String? unit;
      if (_selectedType == HabitType.unit) {
        unit = _unitController.text;
      } else if (_selectedType == HabitType.time) {
        unit = 'minutes';
      }

      final newHabit = Habit(
        name: name,
        frequency: 'daily',
        goalAmount: goalAmount,
        unit: unit,
        type: _selectedType,
        lastChecked: DateTime.now().millisecondsSinceEpoch,
      );

      await DatabaseHelper.instance.insertHabit(newHabit);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Habit'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _habitNameController,
                decoration: const InputDecoration(
                  labelText: 'Habit Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a habit name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Habit Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedType = HabitType.binary;
                        });
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Yes/No'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedType == HabitType.binary ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                        foregroundColor: _selectedType == HabitType.binary ? Theme.of(context).colorScheme.onPrimary : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedType = HabitType.unit;
                        });
                      },
                      icon: const Icon(Icons.numbers),
                      label: const Text('Unit-Based'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedType == HabitType.unit ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                        foregroundColor: _selectedType == HabitType.unit ? Theme.of(context).colorScheme.onPrimary : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedType = HabitType.time;
                        });
                      },
                      icon: const Icon(Icons.timer),
                      label: const Text('Time-Based'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedType == HabitType.time ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                        foregroundColor: _selectedType == HabitType.time ? Theme.of(context).colorScheme.onPrimary : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_selectedType != HabitType.binary) ...[
                TextFormField(
                  controller: _goalAmountController,
                  decoration: InputDecoration(
                    labelText: _selectedType == HabitType.time ? 'Daily Goal (in minutes)' : 'Daily Goal Amount',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a goal';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedType != HabitType.time)
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit (e.g., "liters", "pages")',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a unit';
                      }
                      return null;
                    },
                  ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveHabit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Habit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}