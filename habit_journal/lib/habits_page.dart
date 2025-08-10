import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:habit_journal/habit_tile.dart';
import 'package:habit_journal/menu_drawer.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  List habitList = [
    // [ habitName, habitStarted, timeSpent (sec), timeGoal (min) ]
    ['Exercise', false, 0, 10],
    ['Meditate', false, 0, 50],
    ['Study', false, 0, 100],
    ['Clean', false, 0, 20],
  ];

  TextEditingController newHabitNameController = TextEditingController();
  TextEditingController newHabitGoalController = TextEditingController();

   void createNewHabit() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create new habit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newHabitNameController,
                decoration: const InputDecoration(hintText: "Habit name"),
              ),
              TextField(
                controller: newHabitGoalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: "Goal in minutes"),
              ),
            ],
          ),
          actions: [
            MaterialButton(
              onPressed: () {
                Navigator.of(context).pop();
                newHabitNameController.clear();
                newHabitGoalController.clear();
              },
              child: const Text("Cancel"),
            ),
            MaterialButton(
              onPressed: () {
                setState(() {
                  habitList.add([newHabitNameController.text, false, 0, int.parse(newHabitGoalController.text)]);
                });
                Navigator.of(context).pop();
                newHabitNameController.clear();
                newHabitGoalController.clear();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  

  void habitStarted(int index) {
    var startTime = DateTime.now();
    setState(() {
      habitList[index][1] = !habitList[index][1];
    });

    int elapsedSeconds = habitList[index][2];

    if (habitList[index][1]){
      Timer.periodic(Duration(seconds: 1), (timer){
        setState(() {
          if (!habitList[index][1]) {
            timer.cancel();
          }
          var currentTime = DateTime.now();
          habitList[index][2] = elapsedSeconds + currentTime.difference(startTime).inSeconds;
        });
      
      });
    }
  }
  
  

  void settingsOpened(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(title: Text('Settings for ${habitList[index][0]}'));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: HabitJournalMenuDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.pink,
        title: const Text('Habits'),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<ProfileScreen>(
                  builder: (context) => ProfileScreen(
                    appBar: AppBar(title: const Text('User Profile')),
                    actions: [
                      SignedOutAction((context) {
                        Navigator.of(context).pop();
                      }),
                    ],
                    children: [const Divider()],
                  ),
                ),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        itemCount: habitList.length,
        itemBuilder: ((context, index) {
          return HabitTile(
            habitName: habitList[index][0],
            onTap: () => habitStarted(index),
            settingsTapped: () => settingsOpened(index),
            timeSpent: habitList[index][2],
            timeGoal: habitList[index][3],
            habitStarted: habitList[index][1],
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: createNewHabit,
        child: const Icon(Icons.add),
      ),
    );
  }
}
