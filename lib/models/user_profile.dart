import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/account_labels.dart';

/// The public part of an account, stored in `users/{uid}`.
///
/// Firebase Authentication still holds the real account (and the password
/// hash). This copy exists because the app cannot look up OTHER people's
/// accounts in Firebase Authentication, and a shared list needs to show its
/// members' names.
class UserProfile {
  const UserProfile({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;
  final String? displayName;

  /// "Juan", or the part of the email before the @ if no name is set.
  String get label => nameToShow(displayName: displayName, email: email);

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserProfile(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
    );
  }
}
