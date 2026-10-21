import 'package:flutter/material.dart';

import '../logic/account_labels.dart';
import '../logic/task_filter.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../services/auth_service.dart';
import '../services/list_service.dart';
import '../services/task_service.dart';
import '../theme.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/filter_sort_sheet.dart';
import '../widgets/list_drawer.dart';
import '../widgets/new_list_dialog.dart';
import '../widgets/task_tile.dart';
import 'members_screen.dart';
import 'profile_screen.dart';
import 'task_form_screen.dart';

/// The main screen once signed in: one task list at a time.
///
/// It shows either the user's Personal list or one shared list, chosen from
/// the drawer. It owns the filter/sort state and wires every user action to a
/// [TaskService] call. Every [TaskService] it creates is scoped to [uid], the
/// signed-in user, which is how a user only ever sees their own tasks (plus
/// the shared lists they belong to).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.uid});

  /// The signed-in user's UID, handed over by AuthGate.
  final String uid;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();
  final ListService _lists = ListService();

  /// Every shared list this user belongs to, live, for the drawer.
  late final Stream<List<TaskList>> _myLists = _lists.watchMyLists(widget.uid);

  /// The list on screen: null means Personal.
  TaskList? _list;

  /// The service and task stream for the list on screen. Both are made in
  /// [_useList], once per list, not in build(): build runs often, and a new
  /// stream every time would restart the database listener.
  late TaskService _service;
  late Stream<List<Task>> _tasks;

  FilterState _filter = const FilterState();
  SortOption _sort = SortOption.dateAdded;

  @override
  void initState() {
    super.initState();
    _useList(null);
  }

  void _useList(TaskList? list) {
    _list = list;
    _service = list == null
        ? TaskService.personal(uid: widget.uid)
        : TaskService.sharedList(uid: widget.uid, listId: list.id);
    _tasks = _service.watchTasks();
  }

  void _switchTo(TaskList? list) => setState(() => _useList(list));

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  // ------------------------------------------------------ user actions ---

  Future<void> _openForm({Task? existing}) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(existing: existing, service: _service),
      ),
    );
    if (!mounted || result == null) return;
    _snack(result == 'created' ? 'Task added' : 'Task updated');
  }

  Future<void> _toggleDone(Task task, bool value) async {
    try {
      await _service.setDone(task.id, value);
      _snack(value ? 'Marked as done' : 'Marked as not done');
    } catch (error) {
      _snack('Could not update: $error', isError: true);
    }
  }

  /// DELETE + UNDO.
  ///
  /// The task object is captured in `task` before the delete. The document is
  /// removed from Firestore immediately; the in-memory copy is what Undo uses
  /// to re-create it with the same document ID.
  Future<void> _deleteWithUndo(Task task) async {
    final confirmed = await showDeleteConfirmDialog(context, task.title);
    if (confirmed != true || !mounted) return;

    // Captured now, so Undo restores into the list the task came from even if
    // the user switches lists while the snackbar is showing.
    final service = _service;
    try {
      await service.deleteTask(task.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Deleted "${task.title}"'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                try {
                  await service.restoreTask(task);
                  _snack('Task restored');
                } catch (error) {
                  _snack('Could not restore: $error', isError: true);
                }
              },
            ),
          ),
        );
    } catch (error) {
      _snack('Could not delete: $error', isError: true);
    }
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(context, _filter);
    if (result == null) return;
    setState(() => _filter = result);
  }

  Future<void> _createList() async {
    Navigator.pop(context); // close the drawer
    final name = await showNewListDialog(context);
    if (name == null || !mounted) return;
    try {
      final id = await _lists.createList(ownerId: widget.uid, name: name);
      _switchTo(TaskList(
        id: id,
        name: name,
        ownerId: widget.uid,
        memberIds: [widget.uid],
      ));
      _snack('Created "$name". Open Members to add people.');
    } catch (error) {
      _snack('Could not create the list: $error', isError: true);
    }
  }

  Future<void> _openMembers(TaskList list) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MembersScreen(listId: list.id, uid: widget.uid),
      ),
    );
    if (!mounted) return;
    if (result == 'deleted') {
      _switchTo(null);
      _snack('Deleted "${list.name}"');
    }
  }

  void _openAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _logOut() async {
    final messenger = ScaffoldMessenger.of(context);
    await _auth.signOut();
    // AuthGate now swaps in the sign-in screen.
    messenger.showSnackBar(
      const SnackBar(content: Text('You have been logged out.')),
    );
  }

  // ------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    // The drawer and the title need the user's lists, so the whole screen
    // listens to them. A rename or a new member shows up live.
    return StreamBuilder<List<TaskList>>(
      stream: _myLists,
      builder: (context, listsSnapshot) {
        final lists = listsSnapshot.data ?? const <TaskList>[];
        final current = _currentList(lists, loaded: listsSnapshot.hasData);
        return _buildScaffold(context, lists, current);
      },
    );
  }

  /// The freshest copy of the list on screen. Returns null for Personal, and
  /// also when the shared list is no longer in the user's lists (deleted, or
  /// the owner removed them); [_lostAccess] tells those two apart.
  TaskList? _currentList(List<TaskList> lists, {required bool loaded}) {
    final selected = _list;
    if (selected == null) return null;
    for (final list in lists) {
      if (list.id == selected.id) return list;
    }
    // Not loaded yet: keep showing what we have rather than a false alarm.
    return loaded ? null : selected;
  }

  Widget _buildScaffold(
    BuildContext context,
    List<TaskList> lists,
    TaskList? current,
  ) {
    final user = _auth.currentUser;
    final userName = nameToShow(displayName: user?.displayName, email: user?.email);
    // A shared list was selected but is no longer one of the user's lists.
    final lostAccess = current == null && _list != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(current?.name ?? 'My Tasks'),
            Text(
              current != null
                  ? 'Shared list · ${current.memberIds.length} members'
                  : 'Personal · only you can see these',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
            ),
          ],
        ),
        actions: [
          if (current != null)
            IconButton(
              icon: const Icon(Icons.group_outlined),
              tooltip: 'Members',
              onPressed: () => _openMembers(current),
            ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            initialValue: _sort,
            onSelected: (option) => setState(() => _sort = option),
            itemBuilder: (_) => [
              for (final option in SortOption.values)
                PopupMenuItem(value: option, child: Text(option.label)),
            ],
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _filter.isActive,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filter tasks',
            onPressed: _openFilters,
          ),
          _AccountButton(name: userName, onPressed: _openAccount),
        ],
      ),

      drawer: ListDrawer(
        uid: widget.uid,
        userName: userName,
        userEmail: user?.email ?? '',
        lists: lists,
        currentListId: _list?.id,
        onSelect: (list) {
          Navigator.pop(context); // close the drawer
          _switchTo(list);
        },
        onCreateList: _createList,
        onOpenAccount: () {
          Navigator.pop(context);
          _openAccount();
        },
        onLogOut: () {
          Navigator.pop(context);
          _logOut();
        },
      ),

      floatingActionButton: lostAccess
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            ),

      body: lostAccess ? _noAccess() : _taskList(shared: current != null),
    );
  }

  /// Shown when a shared list on screen was deleted, or the owner removed
  /// this user from it.
  Widget _noAccess() {
    return _Message(
      icon: Icons.lock_outline,
      title: 'You no longer have access to this list',
      subtitle: 'The owner deleted it, or removed you from it.',
      action: FilledButton.tonal(
        onPressed: () => _switchTo(null),
        child: const Text('Back to my Personal list'),
      ),
    );
  }

  Widget _taskList({required bool shared}) {
    // StreamBuilder listens to Firestore. Every database change pushes a new
    // snapshot and rebuilds this subtree — no manual refresh anywhere.
    return StreamBuilder<List<Task>>(
      stream: _tasks,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // In a shared list, an error almost always means the rules just
          // stopped allowing access (removed from the list).
          if (shared) return _noAccess();
          return _Message(
            icon: Icons.cloud_off,
            title: 'Could not load tasks',
            subtitle: '${snapshot.error}',
            isError: true,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allTasks = snapshot.data ?? const <Task>[];

        if (allTasks.isEmpty) {
          return _Message(
            icon: Icons.checklist_rtl,
            title: shared ? 'No tasks in this list yet' : 'No tasks yet',
            subtitle: shared
                ? 'Tap "Add Task" below. Everyone in this list will see it.'
                : 'Tap "Add Task" below to create your first one.',
          );
        }

        // Filtering and sorting happen here, in Dart — not in the query.
        final visible = applyFilterAndSort(allTasks, _filter, _sort);

        return Column(
          children: [
            _SortBar(
              sort: _sort,
              filter: _filter,
              shown: visible.length,
              total: allTasks.length,
              onClearFilters: () =>
                  setState(() => _filter = const FilterState()),
            ),
            Expanded(
              child: visible.isEmpty
                  ? _Message(
                      icon: Icons.filter_alt_off,
                      title: 'No tasks match your filters',
                      subtitle: '${allTasks.length} task(s) are hidden.',
                      action: FilledButton.tonal(
                        onPressed: () =>
                            setState(() => _filter = const FilterState()),
                        child: const Text('Clear filters'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final task = visible[index];
                        return TaskTile(
                          task: task,
                          onToggleDone: (v) => _toggleDone(task, v),
                          onEdit: () => _openForm(existing: task),
                          onDelete: () => _deleteWithUndo(task),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Thin strip under the AppBar showing the active sort and filters, so the
/// user always knows why the list looks the way it does.
class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.sort,
    required this.filter,
    required this.shown,
    required this.total,
    required this.onClearFilters,
  });

  final SortOption sort;
  final FilterState filter;
  final int shown;
  final int total;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Sorted by ${sort.label}  ·  $shown of $total',
            style: theme.textTheme.bodySmall,
          ),
          if (filter.tag != null)
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(tagIcon(filter.tag!), size: 15),
              label: Text(filter.tag!.label),
            ),
          if (filter.priority != null)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(filter.priority!.label),
              backgroundColor:
                  priorityColor(filter.priority!).withValues(alpha: 0.15),
            ),
          if (filter.hideCompleted)
            const Chip(
              visualDensity: VisualDensity.compact,
              label: Text('Completed hidden'),
            ),
          if (filter.isActive)
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

/// Shared empty / error state.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError ? theme.colorScheme.error : theme.hintColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The signed-in user's initials in the AppBar, so it is always obvious whose
/// session this is. Tapping it opens the account page.
class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.name, required this.onPressed});

  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        tooltip: 'Signed in as $name. Open my account',
        onPressed: onPressed,
        icon: CircleAvatar(
          radius: 15,
          backgroundColor: scheme.onPrimary,
          foregroundColor: scheme.primary,
          child: Text(
            initialsOf(name),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
