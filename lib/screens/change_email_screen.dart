import 'package:flutter/material.dart';

import '../logic/auth_errors.dart';
import '../logic/validators.dart';
import '../services/auth_service.dart';
import '../widgets/discard_changes_guard.dart';
import '../widgets/error_banner.dart';
import '../widgets/password_field.dart';
import '../widgets/submit_button.dart';

/// Change the sign-in email. Needs the current password, and only takes
/// effect after the user clicks a link sent to the NEW address (see
/// AuthService.changeEmail for why).
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key, required this.currentEmail});

  final String currentEmail;

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _newEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _busy = false;
  String? _error;

  bool get _hasChanges =>
      _newEmailController.text.isNotEmpty ||
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _newEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newEmail = _newEmailController.text.trim();
    setState(() => _busy = true);
    try {
      await _auth.changeEmail(
        currentPassword: _passwordController.text,
        newEmail: newEmail,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _showCheckInbox(newEmail);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = authErrorMessage(error);
      });
    }
  }

  /// A dialog rather than a SnackBar: the next step happens in the user's
  /// inbox, and a SnackBar would vanish before it could be read.
  Future<void> _showCheckInbox(String newEmail) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.mark_email_unread_outlined),
        title: const Text('Check your new inbox'),
        // "If ... not already used": Firebase does not tell the app whether
        // another account has this email (email enumeration protection).
        content: Text(
          'If $newEmail is not already used by another account, we sent it '
          'a confirmation link.\n\n'
          'Your sign-in email changes only after you click that link. You '
          'will then be signed out; sign back in with $newEmail.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DiscardChangesGuard(
      hasUnsavedChanges: _hasChanges && !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Change email')),
        body: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Current email', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(widget.currentEmail, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newEmailController,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (value) => validateNewEmail(
                  value,
                  currentEmail: widget.currentEmail,
                ),
                decoration: const InputDecoration(
                  labelText: 'New email',
                  helperText: 'We will send a confirmation link here',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _passwordController,
                enabled: !_busy,
                label: 'Current password',
                helperText: 'Confirms it is really you',
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: validateExistingPassword,
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 16),
              ],
              SubmitButton(
                label: 'Send confirmation link',
                busyLabel: 'Sending...',
                icon: Icons.send,
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : () => Navigator.maybePop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
