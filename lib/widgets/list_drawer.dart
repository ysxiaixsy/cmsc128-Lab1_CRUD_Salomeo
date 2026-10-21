import 'package:flutter/material.dart';

import '../logic/account_labels.dart';
import '../models/task_list.dart';

/// The side menu on the task list: switch between your Personal list and the
/// shared lists you belong to, create a shared list, open your account, or
/// log out.
///
/// Like TaskTile, it holds no state and talks to no database: it draws what
/// it's given and reports taps through callbacks. HomeScreen does the work.
class ListDrawer extends StatelessWidget {
  const ListDrawer({
    super.key,
    required this.uid,
    required this.userName,
    required this.userEmail,
    required this.lists,
    required this.currentListId,
    required this.onSelect,
    required this.onCreateList,
    required this.onOpenAccount,
    required this.onLogOut,
  });

  final String uid;
  final String userName;
  final String userEmail;

  /// Every shared list this user belongs to, owned or joined.
  final List<TaskList> lists;

  /// The list on screen now; null means Personal.
  final String? currentListId;

  /// Called with null for Personal, or the chosen shared list.
  final ValueChanged<TaskList?> onSelect;
  final VoidCallback onCreateList;
  final VoidCallback onOpenAccount;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owned = lists.where((l) => l.isOwnedBy(uid)).toList();
    final joined = lists.where((l) => !l.isOwnedBy(uid)).toList();

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Who's signed in, always visible.
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              leading: CircleAvatar(child: Text(initialsOf(userName))),
              title: Text(userName, style: theme.textTheme.titleMedium),
              subtitle: Text(userEmail),
              onTap: onOpenAccount,
            ),
            const Divider(height: 1),

            _Heading('Your tasks'),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Personal'),
              subtitle: const Text('Only you can see these'),
              selected: currentListId == null,
              onTap: () => onSelect(null),
            ),

            _Heading('Shared lists you own'),
            if (owned.isEmpty)
              const _Hint('None yet. Create one and add people to it.'),
            for (final list in owned)
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: Text(list.name),
                subtitle: Text(_memberCount(list)),
                selected: currentListId == list.id,
                onTap: () => onSelect(list),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New shared list'),
              onTap: onCreateList,
            ),

            _Heading('Shared with you'),
            if (joined.isEmpty)
              const _Hint('Lists other people add you to will appear here.'),
            for (final list in joined)
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(list.name),
                subtitle: Text(_memberCount(list)),
                selected: currentListId == list.id,
                onTap: () => onSelect(list),
              ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('My account'),
              onTap: onOpenAccount,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: onLogOut,
            ),
          ],
        ),
      ),
    );
  }

  static String _memberCount(TaskList list) {
    final n = list.memberIds.length;
    return n == 1 ? 'Just you' : '$n members';
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
    );
  }
}
