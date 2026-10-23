// SETUP: run 'flutterfire configure' to generate firebase_options.dart
// See SETUP.md for complete Firebase configuration instructions.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'firebase_options_test.dart';
import 'app.dart';

/// 'test' solo nelle build di staging e delle anteprime (--dart-define=APP_ENV=test).
const String _appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'prod');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: _appEnv == 'test'
        ? TestFirebaseOptions.web
        : DefaultFirebaseOptions.currentPlatform,
  );
  // La sessione deve sopravvivere a refresh, chiusura del browser e standby.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }
  runApp(const AvanzaApp());
}
