import 'package:firebase_core/firebase_core.dart';                  // Add this import
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';                                     // And this import

// TODO(codelab user): Get API key
const clientId = 'YOUR_CLIENT_ID';

void main() async {
  // Add from here...
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // To here.

  runApp(const MyApp(clientId: clientId));
}