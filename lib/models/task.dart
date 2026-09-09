import 'package:cloud_firestore/cloud_firestore.dart';

/// Priority levels. Stored in Firestore as the short string in [value].
///
/// [sortRank] exists because Firestore stores priority as text, and sorting
/// text would give us "high, low, med" alphabetically — which is meaningless.
/// The rank gives a real ordering that the sort logic uses.
enum Priority {
  low('low', 'Low', 0),
  med('med', 'Med', 1),
  high('high', 'High', 2);

  const Priority(this.value, this.label, this.sortRank);

  final String value;
  final String label;
  final int sortRank;

  /// Converts the raw Firestore string back into an enum.
  /// Falls back to [Priority.med] so a malformed document can never crash
  /// the list — remember Firestore enforces no schema of its own.
  static Priority fromValue(String? raw) => Priority.values.firstWhere(
        (p) => p.value == raw,
        orElse: () => Priority.med,
      );
}

/// Category tags, stored in Firestore as the short string in [value].
enum TaskTag {
  school('school', 'School'),
  personal('personal', 'Personal'),
  others('others', 'Others');

  const TaskTag(this.value, this.label);

  final String value;
  final String label;

  static TaskTag fromValue(String? raw) => TaskTag.values.firstWhere(
        (t) => t.value == raw,
        orElse: () => TaskTag.others,
      );
}

/// A single to-do item.
///
/// THIS CLASS IS THE ONLY SCHEMA THIS APP HAS.
/// Firestore is schemaless — it will happily store a document with a misspelled
/// field or a missing due date. The guarantee that every task has the same
/// shape comes from [fromDoc] and [toMap] below, not from the database.
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    required this.tag,
    required this.isDone,
    this.createdAt,
  });

  /// The Firestore document ID. Auto-generated and globally unique, which is
  /// how two tasks with identical titles stay distinct. It lives in the
  /// document's *path*, not inside the document body — which is why [toMap]
  /// deliberately does not write it.
  final String id;

  final String title;
  final DateTime dueDate;
  final Priority priority;
  final TaskTag tag;
  final bool isDone;

  /// Nullable on purpose. It is written with `FieldValue.serverTimestamp()`,
  /// which the *server* fills in. For a few milliseconds after a write the
  /// local copy still has null here, so every consumer must tolerate it.
  final DateTime? createdAt;

  bool get isOverdue => !isDone && dueDate.isBefore(DateTime.now());

  /// READ: Firestore document -> Dart object.
  factory Task.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Task(
      id: doc.id,
      title: (data['title'] as String?) ?? '(untitled)',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      priority: Priority.fromValue(data['priority'] as String?),
      tag: TaskTag.fromValue(data['tag'] as String?),
      isDone: (data['isDone'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// WRITE: Dart object -> Firestore document body.
  ///
  /// `Timestamp` is Firestore's own date type; `DateTime` is Dart's. Converting
  /// here means the rest of the app only ever deals in `DateTime`.
  Map<String, dynamic> toMap() => {
        'title': title,
        'dueDate': Timestamp.fromDate(dueDate),
        'priority': priority.value,
        'tag': tag.value,
        'isDone': isDone,
        // Only included when we already know it (i.e. restoring a deleted
        // task). A brand-new task gets a server timestamp instead.
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };

  Task copyWith({
    String? title,
    DateTime? dueDate,
    Priority? priority,
    TaskTag? tag,
    bool? isDone,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      tag: tag ?? this.tag,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
    );
  }
}
