import 'package:firebase_auth/firebase_auth.dart';

/// THE AUTHENTICATION LAYER. Every Firebase Authentication call in this app
/// lives here — the same idea as TaskService, which holds every Firestore call.
///
/// What this app never does: store, hash, or compare a password itself. Each
/// password travels over HTTPS to Firebase Authentication, which salts and
/// hashes it with scrypt on Google's servers and keeps only the hash. When
/// someone signs in, Firebase hashes the attempt the same way and compares the
/// two hashes. The plain password is never saved anywhere.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ------------------------------------------------------------- SESSION ---

  /// The signed-in user, or null.
  ///
  /// Firebase keeps the session (an ID token plus a long-lived refresh token)
  /// in the app's private storage on the phone and restores it on startup.
  /// That is why closing and reopening the app does not sign anyone out.
  User? get currentUser => _auth.currentUser;

  /// Emits only when someone signs in or signs out. AuthGate listens to this.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Emits on sign-in/out AND whenever the account itself changes, such as a
  /// new display name. ProfileScreen listens to this so its greeting updates
  /// the moment a name is saved.
  Stream<User?> userChanges() => _auth.userChanges();

  // ------------------------------------------------------------ REGISTER ---

  /// Creates the account, then saves the display name onto it.
  ///
  /// Two network calls, in this order, because a display name needs an account
  /// to belong to. Firebase signs the new user in as soon as the first call
  /// succeeds, so AuthGate may already be showing ProfileScreen while the name
  /// is still being saved.
  ///
  /// Returns false if the account was created but the name could not be
  /// saved. The account is still usable, and the name can be set from the
  /// Profile page. Errors from creating the account itself (email already
  /// used, no internet, ...) are thrown to the caller.
  Future<bool> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      await credential.user?.updateDisplayName(displayName);
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  // ------------------------------------------------------ SIGN IN / OUT ---

  /// Sends the email and password to Firebase, which checks them against the
  /// stored hash. On success Firebase saves a session on the phone and
  /// authStateChanges() emits the user.
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Ends the session on this phone: Firebase deletes the stored tokens and
  /// authStateChanges() emits null, so AuthGate shows the sign-in screen.
  Future<void> signOut() => _auth.signOut();

  // ------------------------------------------------------ PASSWORD RESET ---

  /// Asks Firebase to email a password-reset link.
  ///
  /// The link holds a one-time code that expires after 1 hour. It opens a page
  /// Firebase hosts, where the user types a new password. Firebase stores the
  /// new hash, so the old password stops working immediately, and it signs the
  /// account out on every device.
  ///
  /// With email enumeration protection on (Firebase's default), this succeeds
  /// even when no account uses [email] — Firebase just sends nothing. So the
  /// screen must never claim that an account exists.
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // ----------------------------------------------------- PROFILE UPDATES ---

  /// Saves a new display name on the account. userChanges() then emits, which
  /// is what updates the greeting on the Profile page.
  Future<void> updateDisplayName(String displayName) async {
    await _requireUser().updateDisplayName(displayName);
  }

  /// Changing email is two steps on purpose:
  ///   1. Re-check the current password, proving the owner is holding the phone.
  ///   2. Email a confirmation link to the NEW address.
  /// The account's email only changes when that link is clicked, which proves
  /// the new inbox belongs to the user. Firebase then signs the account out
  /// everywhere, and the user signs back in with the new email.
  ///
  /// If the new address already belongs to another account, Firebase silently
  /// sends nothing (email enumeration protection). A duplicate can never be
  /// created, but the app is not told which case happened.
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = await _reauthenticate(currentPassword);
    await user.verifyBeforeUpdateEmail(newEmail);
  }

  /// Re-checks the current password, then sets the new one. Firebase hashes
  /// the new password on its servers and signs out this account's OTHER
  /// sessions. This phone receives fresh tokens and stays signed in.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = await _reauthenticate(currentPassword);
    await user.updatePassword(newPassword);
  }

  /// Fetches the latest copy of the account from Firebase.
  ///
  /// Some changes happen outside the app: clicking an email-change link, or
  /// resetting the password from another device. Firebase revokes the old
  /// session when that happens, so reload() fails, and we sign out so the user
  /// can sign in again with the new details.
  ///
  /// Returns true if the session turned out to be revoked, meaning the user
  /// has just been signed out. Other failures (like no internet) are ignored:
  /// the user stays signed in and the next refresh tries again.
  Future<bool> refreshUser() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.reload();
      return false;
    } on FirebaseAuthException catch (error) {
      if (_sessionEndedCodes.contains(error.code)) {
        await _auth.signOut();
        return true;
      }
      return false;
    }
  }

  /// Error codes that mean "this phone's session is no longer valid".
  static const _sessionEndedCodes = {
    'user-token-expired',
    'invalid-user-token',
    'user-not-found',
    'user-disabled',
  };

  // ------------------------------------------------------------- HELPERS ---

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is signed in.',
      );
    }
    return user;
  }

  /// Signs in again with the current password, right before a sensitive
  /// change. Firebase refuses email/password changes unless the last sign-in
  /// was recent, and asking again also stops someone who picks up an unlocked
  /// phone from taking over the account.
  Future<User> _reauthenticate(String currentPassword) async {
    final user = _requireUser();

    // Every account in this app signs in with an email, so it is never null.
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    try {
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      // Firebase reports a wrong password as 'invalid-credential', which the
      // sign-in screen shows as "Incorrect email or password". Here the email
      // is known to be right, so give the more precise message.
      if (error.code == 'invalid-credential' || error.code == 'wrong-password') {
        throw FirebaseAuthException(
          code: 'wrong-current-password',
          message: 'The current password is incorrect.',
        );
      }
      rethrow;
    }
    return user;
  }
}
