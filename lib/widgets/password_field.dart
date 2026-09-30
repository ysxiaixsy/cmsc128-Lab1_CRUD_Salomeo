import 'package:flutter/material.dart';

/// A password input with a show/hide button.
///
/// Hidden by default so it cannot be read over someone's shoulder, but the
/// user can reveal it to check for typos. Autocorrect and suggestions are off
/// so the keyboard never learns (or suggests) the password.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.helperText,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final String? helperText;

  /// Tells the phone's password manager what this field is:
  /// [AutofillHints.password] to fill a saved password,
  /// [AutofillHints.newPassword] to offer to save a new one.
  final Iterable<String>? autofillHints;

  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscured ? 'Show password' : 'Hide password',
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
