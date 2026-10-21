import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

/// The user directory: every Firestore call about accounts lives here.
///
/// Two collections, both written only by their own account:
///   - `users/{uid}`: the public profile (email, display name), so shared
///     lists can show their members' names;
///   - `emails/{email}`: a lookup table from an exact email to its UID, so an
///     owner can add a member by email.
/// The rules allow reading ONE document of either by its ID, but never listing
/// them, so nobody can harvest every user's email.
///
/// Passwords are not here. They stay hashed inside Firebase Authentication.
class UserService {
  final CollectionReference<Map<String, dynamic>> _users =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference<Map<String, dynamic>> _emails =
      FirebaseFirestore.instance.collection('emails');

  /// Copies the account's email and name from Firebase Authentication into
  /// the directory, if they changed.
  ///
  /// Called when someone signs in or the app starts signed in (AuthGate),
  /// right after registering, and after a name change. Calling it at sign-in
  /// also covers accounts created before Lab 3 and email changes made through
  /// the confirmation link.
  Future<void> syncProfile(User user) async {
    final email = user.email;
    if (email == null) return;

    final profileRef = _users.doc(user.uid);
    final existing = await profileRef.get();
    final oldEmail = existing.data()?['email'] as String?;
    final oldName = existing.data()?['displayName'] as String?;

    // Nothing changed: skip the write.
    if (existing.exists && oldEmail == email && oldName == user.displayName) {
      return;
    }

    // A batch writes everything or nothing.
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      profileRef,
      {
        'email': email,
        'displayName': user.displayName,
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(_emails.doc(email.toLowerCase()), {'uid': user.uid});

    // The email changed: the old address must stop pointing at this account.
    if (oldEmail != null && oldEmail.toLowerCase() != email.toLowerCase()) {
      batch.delete(_emails.doc(oldEmail.toLowerCase()));
    }
    await batch.commit();
  }

  /// The UID of the account using exactly [email], or null if none does.
  Future<String?> findUidByEmail(String email) async {
    final doc = await _emails.doc(email.trim().toLowerCase()).get();
    return doc.data()?['uid'] as String?;
  }

  /// The profiles of the given accounts, in the same order.
  ///
  /// One `get` per account rather than a single query: the rules forbid
  /// listing `users`, and that's the point.
  Future<List<UserProfile>> getProfiles(List<String> uids) {
    return Future.wait(
      uids.map((uid) async => UserProfile.fromDoc(await _users.doc(uid).get())),
    );
  }
}
