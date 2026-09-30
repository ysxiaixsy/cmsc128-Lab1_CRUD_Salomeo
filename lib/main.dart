import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme.dart';

/// Entry point.
///
/// `async` because Firebase must be set up before the first frame is drawn.
/// If runApp ran first, AuthGate could ask Firebase Auth who is signed in
/// before Firebase existed, and crash.
Future<void> main() async {
  // Flutter reaches native Android code over "platform channels".
  // Firebase.initializeApp uses those channels, and they only exist after the
  // binding is initialized. This line is what makes async work legal in main().
  WidgetsFlutterBinding.ensureInitialized();

  // Reads the project settings from the generated firebase_options.dart
  // (gitignored) and sets up the Firebase SDKs for the `jp-todo` project.
  // No network connection opens yet; Auth and Firestore connect on first use.
  // Firebase Auth does restore any saved session from the phone's storage
  // here, which is how AuthGate knows who is signed in on the very first frame.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Tasks',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Signed out -> sign-in screen; signed in -> profile. See AuthGate.
      home: const AuthGate(),
    );
  }
}
