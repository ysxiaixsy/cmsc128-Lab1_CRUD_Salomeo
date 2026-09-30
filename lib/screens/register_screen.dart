import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/auth_errors.dart';
import '../logic/validators.dart';
import '../services/auth_service.dart';
import '../widgets/error_banner.dart';
import '../widgets/password_field.dart';
import '../widgets/submit_button.dart';

/// Create a new account: name, email, password (typed twice).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Grab these BEFORE the await. Once the account exists, AuthGate closes
    // this screen, and its context and controllers go away with it. The
    // ScaffoldMessenger belongs to the whole app, so it is still there.
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();

    setState(() => _busy = true);
    try {
      final nameSaved = await _auth.register(
        displayName: name,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      TextInput.finishAutofillContext();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nameSaved
                ? 'Welcome, $name! Your account is ready.'
                : 'Account created, but your name was not saved. '
                    'You can set it on your profile.',
          ),
        ),
      );
    } catch (error) {
      // The account was NOT created (email taken, no internet, ...), so this
      // screen is still open and can show the reason.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = authErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_busy,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  validator: validateDisplayName,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    helperText: 'Shown on your profile, e.g. "Hello, Juan"',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    helperText: 'You will sign in with this',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _passwordController,
                  enabled: !_busy,
                  label: 'Password',
                  helperText: 'At least $kMinPasswordLength characters',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validateNewPassword,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirmController,
                  enabled: !_busy,
                  label: 'Confirm password',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  validator: (value) => validatePasswordConfirmation(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: 24),

                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: 16),
                ],
                SubmitButton(
                  label: 'Create account',
                  busyLabel: 'Creating account...',
                  icon: Icons.person_add_alt_1,
                  busy: _busy,
                  onPressed: _register,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
