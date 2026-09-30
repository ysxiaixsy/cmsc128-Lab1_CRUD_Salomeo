import 'package:flutter/material.dart';

import '../logic/auth_errors.dart';
import '../logic/validators.dart';
import '../services/auth_service.dart';
import '../widgets/error_banner.dart';
import '../widgets/submit_button.dart';

/// Password recovery, step 1: ask Firebase to email a reset link.
///
/// Steps 2 and 3 happen outside the app. The user opens the link, types a new
/// password on a page Firebase hosts, and Firebase saves the new hash. Then
/// they come back here and sign in with the new password; the old one no
/// longer works.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);

  bool _busy = false;
  String? _error;

  /// Set once a link has been requested; switches the screen to "check your
  /// email".
  String? _sentTo;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _send(_emailController.text.trim());
  }

  Future<void> _send(String email) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await _auth.sendPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sentTo = email;
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: _sentTo == null ? _buildRequestForm() : _buildSent(_sentTo!),
        ),
      ),
    );
  }

  List<Widget> _buildRequestForm() {
    return [
      Text(
        'Enter the email you signed up with. We will send you a link to '
        'choose a new password.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 20),
      Form(
        key: _formKey,
        child: TextFormField(
          controller: _emailController,
          enabled: !_busy,
          autofocus: widget.initialEmail.isEmpty,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: validateEmail,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
      ),
      const SizedBox(height: 24),
      if (_error != null) ...[
        ErrorBanner(_error!),
        const SizedBox(height: 16),
      ],
      SubmitButton(
        label: 'Send reset link',
        busyLabel: 'Sending...',
        icon: Icons.send,
        busy: _busy,
        onPressed: _submit,
      ),
    ];
  }

  List<Widget> _buildSent(String email) {
    final theme = Theme.of(context);

    return [
      const SizedBox(height: 16),
      Icon(
        Icons.mark_email_read_outlined,
        size: 64,
        color: theme.colorScheme.primary,
      ),
      const SizedBox(height: 16),
      Text(
        'Check your email',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      // Worded carefully: "IF an account exists". Saying "we sent you a link"
      // would confirm to a stranger that this email has an account.
      Text(
        'If an account exists for $email, we sent it a link to reset the '
        'password.\n\nThe link expires in 1 hour. If you do not see the '
        'email, check your Spam folder.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge,
      ),
      const SizedBox(height: 32),
      if (_error != null) ...[
        ErrorBanner(_error!),
        const SizedBox(height: 16),
      ],
      FilledButton.icon(
        onPressed: _busy ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.login),
        label: const Text('Back to sign in'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: _busy ? null : () => _send(email),
        child: Text(_busy ? 'Sending...' : 'Send the link again'),
      ),
      TextButton(
        onPressed: _busy ? null : () => setState(() => _sentTo = null),
        child: const Text('Use a different email'),
      ),
    ];
  }
}
