import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart';

/// THE PERSISTENCE LAYER. Every single Firestore call for tasks lives here.
///
/// No screen or widget ever touches `FirebaseFirestore` directly. That means
/// when asked "where does your app talk to the database?", the answer is one
/// file — this one.
///
/// Since Lab 3, a TaskService always works on behalf of ONE signed-in user
/// ([uid]) and on ONE list:
///   - [TaskService.personal]: that user's own tasks, in the `tasks` collection;
///   - [TaskService.sharedList]: the tasks of one shared list, in
///     `lists/{listId}/tasks`.
/// The security rules in firestore.rules enforce the same boundaries on the
/// server, so this file filtering correctly is convenience, not the protection.
class TaskService {
  /// The signed-in user's personal tasks.
  TaskService.personal({required this.uid})
      : listId = null,
        _tasks = FirebaseFirestore.instance.collection('tasks');

  /// The tasks inside one shared list. The rules only allow this if [uid] is
  /// one of the list's members.
  TaskService.sharedList({required this.uid, required String this.listId})
      : _tasks = FirebaseFirestore.instance
            .collection('lists')
            .doc(listId)
            .collection('tasks');

  /// The signed-in user this service acts for.
  final String uid;

  /// Null for personal tasks; the shared list's ID otherwise.
  final String? listId;

  /// Where this service's tasks live. Firestore creates collections implicitly
  /// on the first write; there is no "CREATE TABLE".
  final CollectionReference<Map<String, dynamic>> _tasks;

  bool get isShared => listId != null;

  // ---------------------------------------------------------------- READ ---

  /// Streams the tasks, live.
  ///
  /// `.snapshots()` opens a persistent listener: whenever the data changes —
  /// from this device OR from the Firebase console OR from another phone —
  /// Firestore pushes a new snapshot and the UI rebuilds.
  ///
  /// OWNERSHIP FILTER: personal tasks are asked for with
  /// `where('ownerId', isEqualTo: uid)`. This isn't optional politeness: the
  /// rules refuse any query that COULD return someone else's task, so asking
  /// for the whole `tasks` collection would be denied outright. A shared list
  /// needs no filter — every task in it belongs to the list, and the rules
  /// check membership of the list itself.
  ///
  /// Still no `.orderBy()`: sorting happens in app code (logic/task_filter.dart)
  /// so no composite index is needed.
  Stream<List<Task>> watchTasks() {
    Query<Map<String, dynamic>> query = _tasks;
    if (!isShared) {
      query = query.where('ownerId', isEqualTo: uid);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs.map(Task.fromDoc).toList(),
        );
  }

  // -------------------------------------------------------------- CREATE ---

  /// Adds a new task. `.add()` lets Firestore generate the document ID.
  ///
  /// OWNERSHIP STAMP: `ownerId` is always the signed-in user. The rules reject
  /// a new task whose `ownerId` isn't the person creating it, so nobody can
  /// plant a task in someone else's list.
  Future<void> addTask({
    required String title,
    required DateTime dueDate,
    required Priority priority,
    required TaskTag tag,
  }) {
    return _tasks.add({
      'title': title,
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority.value,
      'tag': tag.value,
      'isDone': false,
      'ownerId': uid,
      // Resolved by Google's servers, not this device — so a wrong phone clock
      // cannot corrupt the "Date Added" ordering.
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // -------------------------------------------------------------- UPDATE ---

  /// Edits an existing task.
  ///
  /// `.update()` merges only the listed fields, leaving everything else alone.
  /// `ownerId` is deliberately NOT listed: an edit can never change who owns a
  /// task (and the rules would refuse it if it tried).
  Future<void> updateTask(Task task) {
    return _tasks.doc(task.id).update({
      'title': task.title,
      'dueDate': Timestamp.fromDate(task.dueDate),
      'priority': task.priority.value,
      'tag': task.tag.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks a task done / not done. A one-field update.
  Future<void> setDone(String id, bool isDone) {
    return _tasks.doc(id).update({
      'isDone': isDone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // -------------------------------------------------------------- DELETE ---

  Future<void> deleteTask(String id) => _tasks.doc(id).delete();

  /// Undo support: re-creates a deleted task.
  ///
  /// Uses `.doc(task.id).set(...)` rather than `.add(...)` so the restored task
  /// keeps its ORIGINAL document ID and original `createdAt`.
  ///
  /// `ownerId` is set to whoever presses Undo. For personal tasks that's the
  /// same person anyway. In a shared list, re-creating a task counts as
  /// creating it, and the rules only accept a new task stamped with the
  /// creator's own ID.
  Future<void> restoreTask(Task task) {
    return _tasks.doc(task.id).set({
      ...task.toMap(),
      'ownerId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
