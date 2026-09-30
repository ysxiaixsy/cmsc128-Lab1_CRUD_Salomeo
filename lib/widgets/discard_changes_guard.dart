import 'package:flutter/material.dart';

/// Wraps an edit screen so that leaving it with unsaved edits asks first,
/// instead of silently throwing the edits away.
///
/// It catches every "go back" gesture: the AppBar back arrow, the phone's
/// back button or swipe, and a Cancel button that calls
/// `Navigator.maybePop`. A plain `Navigator.pop` (used after a successful
/// save) is not intercepted, because there is nothing left to lose.
class DiscardChangesGuard extends StatelessWidget {
  const DiscardChangesGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
  });

  final bool hasUnsavedChanges;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      // When false, Flutter blocks the back gesture and calls
      // onPopInvokedWithResult with didPop == false instead.
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDiscardChangesDialog(context);
        if (discard == true && context.mounted) Navigator.pop(context);
      },
      child: child,
    );
  }
}

/// Returns true only if the user explicitly chose Discard.
Future<bool?> showDiscardChangesDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text('Your edits have not been saved.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
}
