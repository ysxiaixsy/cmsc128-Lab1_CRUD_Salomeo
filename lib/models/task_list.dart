import 'package:cloud_firestore/cloud_firestore.dart';

/// A shared ("collaborative") to-do list.
///
/// Stored in the `lists` collection. Its tasks live in a subcollection,
/// `lists/{id}/tasks`, so the security rules can check membership against
/// this one document.
class TaskList {
  const TaskList({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    this.createdAt,
  });

  final String id;
  final String name;

  /// The UID of the account that created the list. Only the owner can add or
  /// remove members, rename it, or delete it.
  final String ownerId;

  /// The UID of every member, the owner included. This is the "membership
  /// table": the rules let you see the list only if your UID is in here.
  final List<String> memberIds;

  final DateTime? createdAt;

  bool isOwnedBy(String uid) => ownerId == uid;

  factory TaskList.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return TaskList(
      id: doc.id,
      name: (data['name'] as String?) ?? '(untitled list)',
      ownerId: (data['ownerId'] as String?) ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? const []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
