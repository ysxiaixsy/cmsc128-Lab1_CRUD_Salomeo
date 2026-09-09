import 'package:flutter/material.dart';

import '../logic/task_filter.dart';
import '../models/task.dart';
import '../theme.dart';

/// Bottom sheet for choosing filters. Returns the new [FilterState], or null
/// if the user dismissed it without applying.
Future<FilterState?> showFilterSheet(
  BuildContext context,
  FilterState current,
) {
  return showModalBottomSheet<FilterState>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final FilterState initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late FilterState _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // SafeArea keeps the action buttons clear of the system navigation bar,
    // and the scroll view stops the sheet clipping its own content on short
    // screens or when the keyboard is up.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter tasks', style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),

            Text('Tag', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _draft.tag == null,
                  onSelected: (_) =>
                      setState(() => _draft = _draft.copyWith(clearTag: true)),
                ),
                for (final tag in TaskTag.values)
                  ChoiceChip(
                    avatar: Icon(tagIcon(tag), size: 16),
                    label: Text(tag.label),
                    selected: _draft.tag == tag,
                    onSelected: (_) =>
                        setState(() => _draft = _draft.copyWith(tag: tag)),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Priority', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _draft.priority == null,
                  onSelected: (_) => setState(
                    () => _draft = _draft.copyWith(clearPriority: true),
                  ),
                ),
                for (final p in Priority.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _draft.priority == p,
                    selectedColor: priorityColor(p).withValues(alpha: 0.25),
                    onSelected: (_) =>
                        setState(() => _draft = _draft.copyWith(priority: p)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hide completed tasks'),
              value: _draft.hideCompleted,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(hideCompleted: v)),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, const FilterState()),
                    child: const Text('Clear all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _draft),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
