import 'package:flutter/material.dart';
import 'package:habit_journal/theme.dart';

import 'auth_gate.dart';

class Application extends StatelessWidget {
  const Application({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightMode,
      // darkTheme: darkMode,
      // theme: ThemeData(
      //   colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      // ),
      home: AuthGate(clientId: clientId),
      debugShowCheckedModeBanner: false,
    );
  }
}