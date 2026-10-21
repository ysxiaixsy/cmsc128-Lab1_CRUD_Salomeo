import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cmsc128_lab1_crud_salomeo/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

// The owner field is what the security rules check, so it must survive every
// conversion and every edit unchanged.

Task _sample({DateTime? createdAt}) => Task(
      id: 'task123',
      title: 'Lab report',
      dueDate: DateTime(2026, 10, 30, 23, 59),
      priority: Priority.high,
      tag: TaskTag.school,
      isDone: false,
      ownerId: 'alice-uid',
      createdAt: createdAt,
    );

void main() {
  test('toMap writes the owner', () {
    expect(_sample().toMap()['ownerId'], 'alice-uid');
  });

  test('toMap never writes the document ID (it lives in the path)', () {
    expect(_sample().toMap().containsKey('id'), isFalse);
  });

  test('toMap writes createdAt only when it is known', () {
    expect(_sample().toMap().containsKey('createdAt'), isFalse);
    final restored = _sample(createdAt: DateTime(2026, 10, 1)).toMap();
    expect(restored['createdAt'], isA<Timestamp>());
  });

  test('copyWith keeps the owner, the ID and createdAt', () {
    final original = _sample(createdAt: DateTime(2026, 10, 1));
    final edited = original.copyWith(title: 'Final lab report', isDone: true);
    expect(edited.ownerId, 'alice-uid');
    expect(edited.id, 'task123');
    expect(edited.createdAt, original.createdAt);
    expect(edited.title, 'Final lab report');
    expect(edited.isDone, isTrue);
  });
}
