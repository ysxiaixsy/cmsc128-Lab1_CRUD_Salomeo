import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// THE FRONT DOOR. Decides, for the whole app, which screen sits at the root:
///
///   nobody signed in  ->  LoginScreen
///   someone signed in ->  ProfileScreen
///
/// This is what protects the app. ProfileScreen, and everything it opens (the
/// task list, the edit screens), only exists while a user is signed in; there
/// is no other route to them.
///
/// It is a listener rather than a StreamBuilder because on every sign-in or
/// sign-out it must also DO something (clear the screens stacked on top),
/// not just redraw.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();
  late final StreamSubscription<User?> _subscription;

  /// Firebase already restored any saved session during
  /// Firebase.initializeApp, so a signed-in user goes straight to their
  /// profile with no flash of the sign-in screen.
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _subscription = _auth.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    if (!mounted) return;

    if (user?.uid != _user?.uid) {
      // Someone signed in or out. Close every screen stacked on top of this
      // one (the task list, an edit form, Create account, an open dialog...)
      // so nothing from before the change can be reached with Back.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    setState(() => _user = user);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const LoginScreen();

    // The key gives each account its own fresh ProfileScreen, so nothing from
    // a previous user's screen state carries over.
    return ProfileScreen(key: ValueKey(user.uid));
  }
}
