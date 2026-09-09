import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart';

/// THE PERSISTENCE LAYER. Every single Firestore call in this app lives here.
///
/// No screen or widget ever touches `FirebaseFirestore` directly. That means
/// when asked "where does your app talk to the database?", the answer is one
/// file — this one.
class TaskService {
  /// A handle to the `tasks` collection. Note that Firestore creates the
  /// collection implicitly on the first write; there is no "CREATE TABLE".
  final CollectionReference<Map<String, dynamic>> _tasks =
      FirebaseFirestore.instance.collection('tasks');

  // ---------------------------------------------------------------- READ ---

  /// Streams every task, live.
  ///
  /// `.snapshots()` opens a persistent listener: whenever the data changes —
  /// from this device OR from the Firebase console OR from another phone —
  /// Firestore pushes a new snapshot and the UI rebuilds. That is why the app
  /// never needs a refresh button.
  ///
  /// Deliberately NO `.orderBy()` here. Sorting happens in app code
  /// (see logic/task_filter.dart) for two reasons:
  ///   1. `orderBy('createdAt')` silently EXCLUDES documents missing that
  ///      field, so a hand-made document in the console would vanish.
  ///   2. Combining `where` + `orderBy` in Firestore requires hand-built
  ///      composite indexes, and a missing one throws at runtime.
  Stream<List<Task>> watchTasks() {
    return _tasks.snapshots().map(
          (snapshot) => snapshot.docs.map(Task.fromDoc).toList(),
        );
  }

  // -------------------------------------------------------------- CREATE ---

  /// Adds a new task. `.add()` lets Firestore generate the document ID.
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
  /// (`.set()` would REPLACE the whole document and wipe `createdAt`.)
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
  /// keeps its ORIGINAL document ID and original `createdAt`. Without that it
  /// would come back as a brand-new document and jump to the wrong position.
  Future<void> restoreTask(Task task) {
    return _tasks.doc(task.id).set({
      ...task.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
