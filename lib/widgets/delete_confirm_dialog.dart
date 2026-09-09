import 'package:flutter/material.dart';

/// Asks the user to confirm a delete.
///
/// Returns `true` only if the user explicitly pressed Delete. Tapping Cancel or
/// tapping outside the dialog returns null, which the caller treats as "no".
/// This is the "no destructive action without confirmation" requirement — the
/// delete in HomeScreen literally cannot run unless this resolves to true.
Future<bool?> showDeleteConfirmDialog(
  BuildContext context,
  String taskTitle,
) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: const Text('Delete task?'),
      // Naming the task prevents deleting the wrong row by mistake.
      content: Text('"$taskTitle" will be removed from your list.'),
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
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
