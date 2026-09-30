import 'package:firebase_auth/firebase_auth.dart';

/// Turns whatever went wrong into one sentence a user can act on.
///
/// Firebase reports failures as a [FirebaseAuthException] whose `code` is a
/// short id such as 'invalid-credential'. Those ids are for programmers; this
/// switch translates them. Anything unexpected falls through to a generic
/// message that still includes the code, so a bug report can be traced.
String authErrorMessage(Object error) {
  if (error is! FirebaseAuthException) {
    return 'Something went wrong. Please try again.';
  }

  return switch (error.code) {
    // With email enumeration protection on (Firebase's default), a wrong
    // password and an unknown email BOTH arrive as 'invalid-credential'.
    // The app cannot tell them apart — on purpose, so nobody can use the
    // sign-in screen to find out which emails have accounts.
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' ||
    'user-not-found' =>
      'Incorrect email or password.',

    // Created by AuthService when re-checking the password before a change.
    'wrong-current-password' => 'Your current password is incorrect.',

    'invalid-email' => 'That email address is not valid.',
    'email-already-in-use' =>
      'An account already exists for that email. Try signing in instead.',
    'weak-password' ||
    'password-does-not-meet-requirements' =>
      'That password is too weak. Use at least 8 characters.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' =>
      'Too many attempts. Wait a few minutes, then try again.',
    'network-request-failed' =>
      'No internet connection. Check your connection and try again.',
    'requires-recent-login' ||
    'user-token-expired' ||
    'invalid-user-token' ||
    'no-current-user' =>
      'Your session has expired. Please sign in again.',
    'operation-not-allowed' =>
      'Email and password sign-in is not turned on for this app.',
    _ => 'Something went wrong (${error.code}). Please try again.',
  };
}
