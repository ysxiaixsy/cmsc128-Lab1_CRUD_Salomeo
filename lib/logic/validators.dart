/// Form checks for the account screens.
///
/// Every function here is PURE: it takes what the user typed and returns null
/// (valid) or the message to show under the field. No Flutter, no Firebase,
/// which is why test/validators_test.dart can check them without a phone.
///
/// These checks give the user instant, clear feedback. They are NOT the
/// security boundary: Firebase Authentication checks everything again on its
/// own servers, because a modified app could skip this file entirely.
library;

const int kMinPasswordLength = 8;
const int kMaxPasswordLength = 128;
const int kMaxDisplayNameLength = 40;

/// "something @ something . something", with no spaces. Deliberately loose:
/// the real test of an email address is whether mail reaches it.
final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Email is required';
  if (!_emailShape.hasMatch(email)) {
    return 'Enter a valid email, like name@example.com';
  }
  return null;
}

/// For the Change email screen: a valid email that is not the current one.
String? validateNewEmail(String? value, {required String? currentEmail}) {
  final shapeError = validateEmail(value);
  if (shapeError != null) return shapeError;

  // Emails are case-insensitive, so "JP@x.com" is the same as "jp@x.com".
  if (value!.trim().toLowerCase() == currentEmail?.toLowerCase()) {
    return 'That is already your email';
  }
  return null;
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Name is required';
  if (name.length > kMaxDisplayNameLength) {
    return 'Keep your name under $kMaxDisplayNameLength characters';
  }
  return null;
}

/// For CHOOSING a password (sign-up, change password).
///
/// Not trimmed: spaces are legal password characters. Length is the rule that
/// matters most for strength, so there are no "must contain a symbol" rules.
String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Password is required';
  if (password.length < kMinPasswordLength) {
    return 'Use at least $kMinPasswordLength characters';
  }
  if (password.length > kMaxPasswordLength) {
    return 'Use at most $kMaxPasswordLength characters';
  }
  return null;
}

/// For the Change password screen: a valid password that differs from the
/// current one.
String? validateChangedPassword(
  String? value, {
  required String currentPassword,
}) {
  final strengthError = validateNewPassword(value);
  if (strengthError != null) return strengthError;
  if (value == currentPassword) {
    return 'Choose a password different from your current one';
  }
  return null;
}

/// For TYPING an existing password (sign-in, confirming it is really you).
///
/// Only checks that something was typed. Applying the length rule here would
/// wrongly block an account whose password was set under older rules.
String? validateExistingPassword(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  return null;
}

/// The "type it again" field. Catches typos before an account is locked
/// behind a password the user did not mean to set.
String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) return 'Re-type your password';
  if (value != password) return 'Passwords do not match';
  return null;
}

const int kMaxListNameLength = 40;

/// For naming a shared list.
String? validateListName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Give the list a name';
  if (name.length > kMaxListNameLength) {
    return 'Keep the name under $kMaxListNameLength characters';
  }
  return null;
}
