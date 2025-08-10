import 'package:flutter/material.dart';
import 'package:habit_journal/habits_page.dart';
import 'package:habit_journal/journal_page.dart';

class BottomNavigationWidget extends StatefulWidget {
  const BottomNavigationWidget({super.key});

  @override
  State<BottomNavigationWidget> createState() => _BottomNavigationWidgetState();
}

class _BottomNavigationWidgetState extends State<BottomNavigationWidget> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    // final ThemeData theme = Theme.of(context);
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Colors.amber,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.checklist),
            icon: Icon(Icons.checklist),
            label: 'Habits',
          ),
          NavigationDestination(icon: Icon(Icons.note), label: 'Journal'),
        ],
      ),
      body: <Widget>[
        /// Habits page
        HabitsPage(),

        /// JournalPage page
        JournalPage(),
      ][currentPageIndex],
    );
  }
}
