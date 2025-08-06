import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:habit_journal/home.dart';
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
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (asyncSnapshot.hasData) {
            return const BottomNavigationWidget();
          }
          return AuthGate(clientId: clientId);
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
