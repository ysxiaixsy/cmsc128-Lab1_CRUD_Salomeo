import 'package:flutter/material.dart';

import '../logic/auth_errors.dart';
import '../logic/validators.dart';
import '../services/auth_service.dart';
import '../widgets/discard_changes_guard.dart';
import '../widgets/error_banner.dart';
import '../widgets/password_field.dart';
import '../widgets/submit_button.dart';

/// Change the password: current password, new password, new password again.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _busy = false;
  String? _error;

  bool get _hasChanges =>
      _currentController.text.isNotEmpty ||
      _newController.text.isNotEmpty ||
      _confirmController.text.isNotEmpty;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await _auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, 'Password changed');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = authErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasUnsavedChanges: _hasChanges && !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Change password')),
        body: AutofillGroup(
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Other phones signed in to this account will have to sign '
                  'in again with the new password.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                PasswordField(
                  controller: _currentController,
                  enabled: !_busy,
                  label: 'Current password',
                  autofillHints: const [AutofillHints.password],
                  validator: validateExistingPassword,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _newController,
                  enabled: !_busy,
                  label: 'New password',
                  helperText: 'At least $kMinPasswordLength characters',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => validateChangedPassword(
                    value,
                    currentPassword: _currentController.text,
                  ),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirmController,
                  enabled: !_busy,
                  label: 'Confirm new password',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => validatePasswordConfirmation(
                    value,
                    _newController.text,
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: 16),
                ],
                SubmitButton(
                  label: 'Change password',
                  busyLabel: 'Changing...',
                  icon: Icons.key,
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
      ),
    );
  }
}
