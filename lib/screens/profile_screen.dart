import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic/account_labels.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';
import 'edit_name_screen.dart';
import 'home_screen.dart';

/// The protected page every sign-in lands on: "Hello, `name`", the account's
/// details and settings, a way into the task list, and Log out.
///
/// It only ever exists while someone is signed in, because AuthGate is the
/// only thing that creates it.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();

  /// userChanges(), not authStateChanges(): it also fires when the display
  /// name changes, so the greeting updates as soon as a new name is saved.
  late final Stream<User?> _userStream = _auth.userChanges();

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Look for changes made outside the app (a clicked email-change link, a
    // password reset from another device): once when this page opens, and
    // again every time the user switches back to the app.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    // Captured first: if the session was revoked, this page is about to be
    // replaced by the sign-in screen, but the app-wide messenger remains.
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

  Future<void> _logOut() async {
    final messenger = ScaffoldMessenger.of(context);
    await _auth.signOut();
    // AuthGate now swaps in the sign-in screen.
    messenger.showSnackBar(
      const SnackBar(content: Text('You have been logged out.')),
    );
  }

  void _openTasks() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  /// Opens an edit screen. If it saved something, it pops with a success
  /// message, which is shown here.
  Future<void> _openEditor(Widget screen) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _userStream,
      initialData: _auth.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          // Only visible for the instant between signing out and AuthGate
          // swapping in the sign-in screen.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildProfile(context, user);
      },
    );
  }

  Widget _buildProfile(BuildContext context, User user) {
    final theme = Theme.of(context);
    final name = nameToShow(displayName: user.displayName, email: user.email);
    final savedName = user.displayName?.trim() ?? '';
    final email = user.email ?? '';
    final joined = user.metadata.creationTime;

    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          // Lets pull-to-refresh work even when the content fits on screen.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            // ------------------------------------------------ greeting ---
            Center(
              child: CircleAvatar(
                radius: 40,
                child: Text(
                  initialsOf(name),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hello, $name',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Chip(
                avatar: Icon(Icons.verified_user, size: 18, color: kLowColor),
                label: Text('Signed in'),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _openTasks,
              icon: const Icon(Icons.checklist),
              label: const Text('Open My Tasks'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 32),

            // ------------------------------------------------ settings ---
            Text('Account settings', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Name'),
                    subtitle: Text(savedName.isEmpty ? 'Not set' : savedName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _openEditor(EditNameScreen(currentName: savedName)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(email),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _openEditor(ChangeEmailScreen(currentEmail: email)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Password'),
                    subtitle: const Text('Change your password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openEditor(const ChangePasswordScreen()),
                  ),
                ],
              ),
            ),
            if (joined != null) ...[
              const SizedBox(height: 12),
              Text(
                'Member since ${DateFormat.yMMMMd().format(joined)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 32),

            OutlinedButton.icon(
              onPressed: _logOut,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
