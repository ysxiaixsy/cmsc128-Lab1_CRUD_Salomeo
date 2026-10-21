import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// THE FRONT DOOR. Decides, for the whole app, which screen sits at the root:
///
///   nobody signed in  ->  LoginScreen
///   someone signed in ->  HomeScreen, showing THAT user's own task list
///
/// Since Lab 3, signing in lands straight on the task list, as the brief
/// requires. HomeScreen is built with the signed-in user's UID, and every task
/// query it makes is scoped to that UID, so a user always lands on their own
/// list, never someone else's.
///
/// It is a listener rather than a StreamBuilder because on every sign-in or
/// sign-out it must also DO something (clear the screens stacked on top, sync
/// the user directory), not just redraw.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();
  final UserService _users = UserService();
  late final StreamSubscription<User?> _subscription;
  late final AppLifecycleListener _lifecycle;

  /// Firebase already restored any saved session during
  /// Firebase.initializeApp, so a signed-in user goes straight to their tasks
  /// with no flash of the sign-in screen.
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _subscription = _auth.authStateChanges().listen(_onAuthChanged);

    // Look for changes made outside the app (a clicked email-change link, a
    // password reset from another device) every time the user comes back.
    _lifecycle = AppLifecycleListener(onResume: _checkSession);

    final user = _user;
    if (user != null) _syncProfile(user);
  }

  void _onAuthChanged(User? user) {
    if (!mounted) return;

    if (user?.uid != _user?.uid) {
      // Someone signed in or out. Close every screen stacked on top of this
      // one (a profile page, an edit form, Create account, an open dialog...)
      // so nothing from before the change can be reached with Back.
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (user != null) _syncProfile(user);
    }
    setState(() => _user = user);
  }

  /// Keeps `users/{uid}` and `emails/{email}` in step with the account.
  /// Best effort: if it fails (no internet), the app still works and the next
  /// sign-in tries again.
  Future<void> _syncProfile(User user) async {
    try {
      await _users.syncProfile(user);
    } catch (_) {
      // Ignored on purpose; see above.
    }
  }

  Future<void> _checkSession() async {
    if (!mounted || _user == null) return;
    // Captured first: if the session was revoked, the screen is about to
    // change, but the app-wide messenger remains.
    final messenger = ScaffoldMessenger.of(context);

    final signedOut = await _auth.refreshUser();
    if (signedOut) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your sign-in details changed. Please sign in again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const LoginScreen();

    // The key gives each account its own fresh HomeScreen, so nothing from a
    // previous user's screen (their selected list, their filters) carries over.
    return HomeScreen(key: ValueKey(user.uid), uid: user.uid);
  }
}
