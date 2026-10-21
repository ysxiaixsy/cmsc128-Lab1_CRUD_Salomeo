import 'package:flutter/material.dart';

import '../logic/account_labels.dart';
import '../logic/validators.dart';
import '../models/task_list.dart';
import '../models/user_profile.dart';
import '../services/list_service.dart';
import '../services/user_service.dart';
import '../widgets/error_banner.dart';
import '../widgets/submit_button.dart';

/// Who is in a shared list. The owner can add people by email, remove them,
/// and delete the list; everyone else can only look.
///
/// Hiding the owner-only controls is just good manners for the screen. The
/// real check is in firestore.rules: only the list's owner may change
/// `memberIds` or delete the list, whatever this screen shows.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, required this.listId, required this.uid});

  final String listId;

  /// The signed-in user.
  final String uid;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _lists = ListService();
  final _users = UserService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  late final Stream<TaskList?> _listStream = _lists.watchList(widget.listId);

  bool _busy = false;
  String? _error;

  // Member profiles, fetched again only when the member list changes.
  Future<List<UserProfile>>? _profiles;
  String _profilesKey = '';

  Future<List<UserProfile>> _profilesFor(List<String> memberIds) {
    final key = memberIds.join(',');
    if (key != _profilesKey || _profiles == null) {
      _profilesKey = key;
      _profiles = _users.getProfiles(memberIds);
    }
    return _profiles!;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _addMember(TaskList list) async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    setState(() => _busy = true);
    try {
      // Email -> UID, through the `emails` lookup table.
      final memberUid = await _users.findUidByEmail(email);
      if (memberUid == null) {
        return _fail('No account uses $email. They need to sign up first.');
      }
      if (memberUid == widget.uid) {
        return _fail("That's your own email. You're already in this list.");
      }
      if (list.memberIds.contains(memberUid)) {
        return _fail('$email is already a member.');
      }

      await _lists.addMember(list.id, memberUid);
      if (!mounted) return;
      _emailController.clear();
      setState(() => _busy = false);
      _snack('Added $email. They can see this list now.');
    } catch (error) {
      _fail('Could not add that person: $error');
    }
  }

  Future<void> _removeMember(TaskList list, UserProfile member) async {
    final confirmed = await _confirm(
      title: 'Remove ${member.label}?',
      message: 'They lose access to "${list.name}" and its tasks immediately.',
      action: 'Remove',
    );
    if (confirmed != true || !mounted) return;
    try {
      await _lists.removeMember(list.id, member.uid);
      _snack('Removed ${member.label}');
    } catch (error) {
      _snack('Could not remove: $error');
    }
  }

  Future<void> _deleteList(TaskList list) async {
    final confirmed = await _confirm(
      title: 'Delete "${list.name}"?',
      message: 'The list and all of its tasks are deleted for every member. '
          'This cannot be undone.',
      action: 'Delete list',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _lists.deleteList(list.id);
      if (!mounted) return;
      // HomeScreen sees 'deleted', switches to Personal, and says so.
      Navigator.pop(context, 'deleted');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not delete the list: $error');
    }
  }

  /// A confirmation dialog; true only if the user chose [action].
  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskList?>(
      stream: _listStream,
      builder: (context, snapshot) {
        // After the first event, a null list means it was deleted.
        final deleted = snapshot.connectionState == ConnectionState.active &&
            snapshot.data == null;
        if (snapshot.hasError || deleted) {
          return _Gone(
            message: snapshot.hasError
                ? 'You no longer have access to this list.'
                : 'This list no longer exists.',
          );
        }
        final list = snapshot.data;
        if (list == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return _buildMembers(context, list);
      },
    );
  }

  Widget _buildMembers(BuildContext context, TaskList list) {
    final theme = Theme.of(context);
    final isOwner = list.isOwnedBy(widget.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(list.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            isOwner
                ? 'You own this list. Everyone below can see and edit its tasks.'
                : 'This list is shared with you. Only its owner can add or remove members.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          if (isOwner) ...[
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _addMember(list),
                validator: validateEmail,
                decoration: const InputDecoration(
                  labelText: 'Add someone by email',
                  helperText: 'They need a My Tasks account',
                  prefixIcon: Icon(Icons.person_add_alt),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: 12),
            ],
            SubmitButton(
              label: 'Add member',
              busyLabel: 'Adding...',
              icon: Icons.group_add,
              busy: _busy,
              onPressed: () => _addMember(list),
            ),
            const SizedBox(height: 28),
          ],

          Text(
            'Members (${list.memberIds.length})',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<UserProfile>>(
            future: _profilesFor(list.memberIds),
            builder: (context, profiles) {
              if (!profiles.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final member in profiles.data!)
                      ListTile(
                        leading: CircleAvatar(child: Text(initialsOf(member.label))),
                        title: Text(
                          member.uid == widget.uid
                              ? '${member.label} (you)'
                              : member.label,
                        ),
                        subtitle: Text(member.email ?? ''),
                        trailing: member.uid == list.ownerId
                            ? const Chip(label: Text('Owner'))
                            : isOwner
                                ? IconButton(
                                    icon: const Icon(Icons.person_remove_outlined),
                                    tooltip: 'Remove ${member.label}',
                                    onPressed: () => _removeMember(list, member),
                                  )
                                : null,
                      ),
                  ],
                ),
              );
            },
          ),

          if (isOwner) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _deleteList(list),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Delete this list'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when the list was deleted, or the owner removed this user, while the
/// Members screen was open.
class _Gone extends StatelessWidget {
  const _Gone({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Theme.of(context).hintColor),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
