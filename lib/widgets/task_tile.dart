import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../theme.dart';

/// One row in the task list.
///
/// This widget is "dumb": it holds no state and talks to no database. It just
/// draws a [Task] and reports taps upward through its callbacks. All the
/// actual work happens in HomeScreen.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final ValueChanged<bool> onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueText = DateFormat('MMM d, y  h:mm a').format(task.dueDate);

    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: task.isDone,
                    onChanged: (v) => onToggleDone(v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        // The visual signal for a completed task.
                        decoration:
                            task.isDone ? TextDecoration.lineThrough : null,
                        color: task.isDone
                            ? theme.disabledColor
                            : theme.textTheme.titleMedium?.color,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit task',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete task',
                    color: theme.colorScheme.error,
                    onPressed: onDelete,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Due date, which turns red once it is in the past.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          task.isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.schedule,
                          size: 15,
                          color: task.isOverdue
                              ? theme.colorScheme.error
                              : theme.hintColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.isOverdue ? '$dueText  ·  Overdue' : dueText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: task.isOverdue
                                ? theme.colorScheme.error
                                : theme.hintColor,
                            fontWeight: task.isOverdue ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ),
                    _Chip(
                      label: task.priority.label,
                      color: priorityColor(task.priority),
                    ),
                    _Chip(
                      label: task.tag.label,
                      color: theme.colorScheme.primary,
                      icon: tagIcon(task.tag),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small colour-coded pill used for priority and tag.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
