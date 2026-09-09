import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

/// Entry point.
///
/// `async` because the Firebase connection must be open before the first frame
/// is drawn. If we called runApp first, HomeScreen could ask Firestore for data
/// before the connection existed and crash.
Future<void> main() async {
  // Flutter reaches native Android code over "platform channels".
  // Firebase.initializeApp uses those channels, and they only exist after the
  // binding is initialized. This line is what makes async work legal in main().
  WidgetsFlutterBinding.ensureInitialized();

  // Reads credentials from the generated firebase_options.dart (gitignored)
  // and connects to the `jp-todo` Firebase project.
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
      home: const HomeScreen(),
    );
  }
}
