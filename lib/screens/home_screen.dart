import 'package:flutter/material.dart';

import '../logic/task_filter.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../theme.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/filter_sort_sheet.dart';
import '../widgets/task_tile.dart';
import 'task_form_screen.dart';

/// The main list screen. Owns the filter/sort state and wires every user
/// action to a [TaskService] call.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TaskService _service = TaskService();

  FilterState _filter = const FilterState();
  SortOption _sort = SortOption.dateAdded;

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
      MaterialPageRoute(builder: (_) => TaskFormScreen(existing: existing)),
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

    try {
      await _service.deleteTask(task.id);
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
                  await _service.restoreTask(task);
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

  // ------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
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
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),

      // StreamBuilder listens to Firestore. Every database change pushes a new
      // snapshot and rebuilds this subtree — no manual refresh anywhere.
      body: StreamBuilder<List<Task>>(
        stream: _service.watchTasks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
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
            return const _Message(
              icon: Icons.checklist_rtl,
              title: 'No tasks yet',
              subtitle: 'Tap "Add Task" below to create your first one.',
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
      ),
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
