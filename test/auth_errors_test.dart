import 'package:cmsc128_lab1_crud_salomeo/logic/auth_errors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseAuthException _error(String code) => FirebaseAuthException(code: code);

void main() {
  test('wrong password and unknown email get the SAME message', () {
    // This is what stops the sign-in screen from revealing which emails
    // have accounts.
    const expected = 'Incorrect email or password.';
    expect(authErrorMessage(_error('invalid-credential')), expected);
    expect(authErrorMessage(_error('wrong-password')), expected);
    expect(authErrorMessage(_error('user-not-found')), expected);
  });

  test('duplicate sign-up says so clearly', () {
    expect(
      authErrorMessage(_error('email-already-in-use')),
      contains('already exists'),
    );
  });

  test('re-check failures name the current password', () {
    expect(
      authErrorMessage(_error('wrong-current-password')),
      'Your current password is incorrect.',
    );
  });

  test('offline and rate-limit errors are explained', () {
    expect(
      authErrorMessage(_error('network-request-failed')),
      contains('No internet'),
    );
    expect(
      authErrorMessage(_error('too-many-requests')),
      contains('Too many attempts'),
    );
  });

  test('unknown codes fall back but keep the code for debugging', () {
    expect(authErrorMessage(_error('brand-new-code')), contains('brand-new-code'));
  });

  test('non-Firebase errors get a generic message', () {
    expect(
      authErrorMessage(Exception('boom')),
      'Something went wrong. Please try again.',
    );
  });
}
