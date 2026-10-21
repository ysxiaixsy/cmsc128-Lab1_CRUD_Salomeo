import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task_list.dart';

/// Every Firestore call about shared lists lives here.
///
/// A list document holds its name, its owner, and `memberIds`: the UIDs of
/// everyone who can see it, owner included. The security rules use that array
/// to decide who may read the list and its tasks.
class ListService {
  final CollectionReference<Map<String, dynamic>> _lists =
      FirebaseFirestore.instance.collection('lists');

  /// Every list [uid] belongs to: the ones they own and the ones they were
  /// added to. `arrayContains` matches documents whose `memberIds` include
  /// [uid], which is exactly what the read rule requires, so it's allowed.
  Stream<List<TaskList>> watchMyLists(String uid) {
    return _lists.where('memberIds', arrayContains: uid).snapshots().map(
      (snapshot) {
        final lists = snapshot.docs.map(TaskList.fromDoc).toList();
        lists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return lists;
      },
    );
  }

  /// One list, live. Emits null if the list no longer exists, and reports an
  /// error if you lose access to it, because the rules stop allowing it.
  Stream<TaskList?> watchList(String listId) {
    return _lists.doc(listId).snapshots().map(
          (doc) => doc.exists ? TaskList.fromDoc(doc) : null,
        );
  }

  /// Creates a list owned by [ownerId], with the owner as its only member.
  /// Returns the new list's ID.
  Future<String> createList({required String ownerId, required String name}) async {
    final ref = await _lists.add({
      'name': name,
      'ownerId': ownerId,
      'memberIds': [ownerId],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Adds a member. `arrayUnion` adds the UID only if it isn't already there.
  Future<void> addMember(String listId, String memberUid) {
    return _lists.doc(listId).update({
      'memberIds': FieldValue.arrayUnion([memberUid]),
    });
  }

  /// Removes a member. They lose access to the list and its tasks at once.
  Future<void> removeMember(String listId, String memberUid) {
    return _lists.doc(listId).update({
      'memberIds': FieldValue.arrayRemove([memberUid]),
    });
  }

  /// Deletes a list AND its tasks.
  ///
  /// Firestore doesn't delete a subcollection when its parent goes, so the
  /// tasks are deleted first, in one batch with the list (all or nothing).
  Future<void> deleteList(String listId) async {
    final listRef = _lists.doc(listId);
    final tasks = await listRef.collection('tasks').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final task in tasks.docs) {
      batch.delete(task.reference);
    }
    batch.delete(listRef);
    await batch.commit();
  }
}
