import 'package:flutter/material.dart';

/// The main button on every account form.
///
/// While [busy] it shows a spinner and ignores taps, so one impatient double
/// tap can never send the same request (e.g. "create account") twice.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final String busyLabel;
  final IconData icon;
  final bool busy;

  /// Null disables the button (for example, when nothing has been edited).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(busy ? busyLabel : label),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }
}
