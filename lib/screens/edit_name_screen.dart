import 'package:flutter/material.dart';

import '../logic/auth_errors.dart';
import '../logic/validators.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../widgets/discard_changes_guard.dart';
import '../widgets/error_banner.dart';
import '../widgets/submit_button.dart';

/// Change the display name used in the "Hello, `name`" greeting.
class EditNameScreen extends StatefulWidget {
  const EditNameScreen({super.key, required this.currentName});

  final String currentName;

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.currentName);

  bool _busy = false;
  String? _error;

  bool get _hasChanges => _nameController.text.trim() != widget.currentName;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await _auth.updateDisplayName(_nameController.text.trim());

      // Shared lists show members' names from the user directory, so update
      // it too. Best effort: the next sign-in syncs it anyway.
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await UserService().syncProfile(user);
        } catch (_) {}
      }
      if (!mounted) return;
      // The message is shown by ProfileScreen, which is underneath.
      Navigator.pop(context, 'Name updated');
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
        appBar: AppBar(title: const Text('Edit name')),
        body: Form(
          key: _formKey,
          // Rebuild on every keystroke so the Save button and the discard
          // guard always know whether anything has changed.
          onChanged: () => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_busy,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                maxLength: kMaxDisplayNameLength,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                validator: validateDisplayName,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  helperText: 'Shown in the greeting on your profile',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 16),
              ],
              SubmitButton(
                label: 'Save name',
                busyLabel: 'Saving...',
                icon: Icons.save,
                busy: _busy,
                // Disabled until something actually changed.
                onPressed: _hasChanges ? _save : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                // maybePop (not pop) so the discard guard gets a say.
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
