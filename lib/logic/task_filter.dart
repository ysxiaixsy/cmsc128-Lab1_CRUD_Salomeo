import '../models/task.dart';

/// The four sort orders required by the brief.
enum SortOption {
  dateAdded('Date Added'),
  dueDate('Due Date'),
  priority('Priority'),
  tag('Tag');

  const SortOption(this.label);
  final String label;
}

/// Which filters are currently switched on. `null` means "All".
class FilterState {
  const FilterState({
    this.tag,
    this.priority,
    this.hideCompleted = false,
  });

  final TaskTag? tag;
  final Priority? priority;
  final bool hideCompleted;

  bool get isActive => tag != null || priority != null || hideCompleted;

  /// `clearTag` / `clearPriority` are needed because passing `null` to
  /// copyWith normally means "leave unchanged", so there would otherwise be
  /// no way to reset a filter back to "All".
  FilterState copyWith({
    TaskTag? tag,
    Priority? priority,
    bool? hideCompleted,
    bool clearTag = false,
    bool clearPriority = false,
  }) {
    return FilterState(
      tag: clearTag ? null : (tag ?? this.tag),
      priority: clearPriority ? null : (priority ?? this.priority),
      hideCompleted: hideCompleted ?? this.hideCompleted,
    );
  }
}

/// Filters and sorts the task list.
///
/// This is a PURE FUNCTION — same input always gives the same output, and it
/// touches no database and no UI. This is the answer to "is your sorting done
/// in the database query or in application code?": application code, here.
///
/// The tradeoff: this reads every task into memory, which is fine for tens of
/// tasks but would not scale to thousands. At that size the filters would move
/// into the Firestore query and we would build composite indexes for them.
List<Task> applyFilterAndSort(
  List<Task> tasks,
  FilterState filter,
  SortOption sort,
) {
  // 1. FILTER — keep only tasks matching every active condition.
  final filtered = tasks.where((task) {
    if (filter.tag != null && task.tag != filter.tag) return false;
    if (filter.priority != null && task.priority != filter.priority) {
      return false;
    }
    if (filter.hideCompleted && task.isDone) return false;
    return true;
  }).toList();

  // 2. SORT — `sort` mutates the list in place, which is safe because
  //    `.where().toList()` above already gave us a fresh copy.
  switch (sort) {
    case SortOption.dateAdded:
      // Newest first. A null createdAt means the server has not confirmed the
      // write yet, so that task was created just now and sorts to the top.
      filtered.sort((a, b) {
        if (a.createdAt == null) return -1;
        if (b.createdAt == null) return 1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

    case SortOption.dueDate:
      // Soonest deadline first.
      filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    case SortOption.priority:
      // High -> Med -> Low, then soonest due date breaks ties.
      filtered.sort((a, b) {
        final byRank = b.priority.sortRank.compareTo(a.priority.sortRank);
        return byRank != 0 ? byRank : a.dueDate.compareTo(b.dueDate);
      });

    case SortOption.tag:
      // Groups tasks by tag (School, Personal, Others), then by due date.
      filtered.sort((a, b) {
        final byTag = a.tag.index.compareTo(b.tag.index);
        return byTag != 0 ? byTag : a.dueDate.compareTo(b.dueDate);
      });
  }

  return filtered;
}
