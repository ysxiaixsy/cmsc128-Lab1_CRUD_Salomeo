import 'package:cmsc128_lab1_crud_salomeo/logic/account_labels.dart';
import 'package:cmsc128_lab1_crud_salomeo/logic/validators.dart';
import 'package:flutter_test/flutter_test.dart';

// Run with:  flutter test
// These run on the computer — no phone or emulator needed — because the
// functions under test are pure Dart.

void main() {
  group('validateEmail', () {
    test('rejects empty and blank input', () {
      expect(validateEmail(null), 'Email is required');
      expect(validateEmail(''), 'Email is required');
      expect(validateEmail('   '), 'Email is required');
    });

    test('rejects addresses with the wrong shape', () {
      for (final bad in ['jp', 'jp@', '@x.com', 'jp@x', 'j p@x.com']) {
        expect(validateEmail(bad), isNotNull, reason: bad);
      }
    });

    test('accepts normal addresses, ignoring surrounding spaces', () {
      expect(validateEmail('jp@example.com'), isNull);
      expect(validateEmail('  jp+test1@gmail.com  '), isNull);
    });
  });

  group('validateNewEmail', () {
    test('rejects the current email, ignoring letter case', () {
      expect(
        validateNewEmail('JP@Example.com', currentEmail: 'jp@example.com'),
        'That is already your email',
      );
    });

    test('accepts a different valid email', () {
      expect(
        validateNewEmail('new@example.com', currentEmail: 'jp@example.com'),
        isNull,
      );
    });

    test('still checks the shape first', () {
      expect(
        validateNewEmail('nope', currentEmail: 'jp@example.com'),
        isNotNull,
      );
    });
  });

  group('validateDisplayName', () {
    test('requires a non-blank name', () {
      expect(validateDisplayName(''), 'Name is required');
      expect(validateDisplayName('   '), 'Name is required');
    });

    test('limits the length', () {
      expect(validateDisplayName('a' * kMaxDisplayNameLength), isNull);
      expect(validateDisplayName('a' * (kMaxDisplayNameLength + 1)), isNotNull);
    });
  });

  group('validateNewPassword', () {
    test('enforces the minimum length', () {
      expect(validateNewPassword(''), 'Password is required');
      expect(validateNewPassword('a' * (kMinPasswordLength - 1)), isNotNull);
      expect(validateNewPassword('a' * kMinPasswordLength), isNull);
    });

    test('enforces the maximum length', () {
      expect(validateNewPassword('a' * kMaxPasswordLength), isNull);
      expect(validateNewPassword('a' * (kMaxPasswordLength + 1)), isNotNull);
    });

    test('counts spaces as characters (no trimming)', () {
      expect(validateNewPassword('   abcde'), isNull);
    });
  });

  group('validateChangedPassword', () {
    test('rejects reusing the current password', () {
      expect(
        validateChangedPassword('samepass1', currentPassword: 'samepass1'),
        'Choose a password different from your current one',
      );
    });

    test('accepts a different, long-enough password', () {
      expect(
        validateChangedPassword('newpass12', currentPassword: 'oldpass12'),
        isNull,
      );
    });
  });

  group('validateExistingPassword', () {
    test('only requires something to be typed', () {
      expect(validateExistingPassword(''), 'Password is required');
      expect(validateExistingPassword('abc'), isNull);
    });
  });

  group('validatePasswordConfirmation', () {
    test('must match exactly', () {
      expect(validatePasswordConfirmation('', 'secret12'), isNotNull);
      expect(
        validatePasswordConfirmation('secret13', 'secret12'),
        'Passwords do not match',
      );
      expect(validatePasswordConfirmation('secret12', 'secret12'), isNull);
    });
  });

  group('nameToShow', () {
    test('prefers the display name', () {
      expect(nameToShow(displayName: 'JP', email: 'jp@x.com'), 'JP');
    });

    test('falls back to the part of the email before @', () {
      expect(nameToShow(displayName: null, email: 'juan@x.com'), 'juan');
      expect(nameToShow(displayName: '  ', email: 'juan@x.com'), 'juan');
    });

    test('has a last-resort fallback', () {
      expect(nameToShow(), 'there');
    });
  });

  group('initialsOf', () {
    test('takes the first and last word', () {
      expect(initialsOf('Juan Dela Cruz'), 'JC');
      expect(initialsOf('jp salomeo'), 'JS');
    });

    test('handles one word and empty input', () {
      expect(initialsOf('jp'), 'J');
      expect(initialsOf('   '), '?');
    });
  });
}
