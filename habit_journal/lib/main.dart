import 'package:firebase_core/firebase_core.dart'; // Add this import
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart'; // And this import

const clientId = 'YOUR_CLIENT_ID';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const Application(clientId: clientId));
}
