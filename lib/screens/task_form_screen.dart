import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../services/task_service.dart';
import '../theme.dart';

/// ONE screen used for both CREATE and UPDATE.
///
/// If [existing] is null we are adding a new task; otherwise we are editing
/// that task. Sharing the screen means the validation rules and the field
/// layout can never drift apart between "add" and "edit".
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.existing});

  final Task? existing;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = TaskService();

  late final TextEditingController _titleController =
      TextEditingController(text: widget.existing?.title ?? '');

  late DateTime? _dueDate = widget.existing?.dueDate;
  late Priority _priority = widget.existing?.priority ?? Priority.med;
  late TaskTag _tag = widget.existing?.tag ?? TaskTag.school;

  bool _dueDateTouched = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// Date first, then time — combined into a single DateTime, because the
  /// data model stores due date and due time as one field.
  Future<void> _pickDueDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _dueDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _dueDateTouched = true;
    });
  }

  Future<void> _save() async {
    setState(() => _dueDateTouched = true);

    // Both guards must pass: the text field validator AND the due date.
    final titleOk = _formKey.currentState?.validate() ?? false;
    if (!titleOk || _dueDate == null) return;

    setState(() => _saving = true);

    try {
      if (_isEditing) {
        // UPDATE — copyWith keeps the original id and createdAt.
        await _service.updateTask(
          widget.existing!.copyWith(
            title: _titleController.text.trim(),
            dueDate: _dueDate,
            priority: _priority,
            tag: _tag,
          ),
        );
      } else {
        // CREATE
        await _service.addTask(
          title: _titleController.text.trim(),
          dueDate: _dueDate!,
          priority: _priority,
          tag: _tag,
        );
      }

      if (!mounted) return;
      // The result string tells HomeScreen which SnackBar to show.
      Navigator.pop(context, _isEditing ? 'updated' : 'created');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Could not save: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueMissing = _dueDateTouched && _dueDate == null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Task' : 'Add Task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g. Finish CMSC 128 lab report',
                prefixIcon: Icon(Icons.title),
              ),
              // Runs on every validate() call. Returning a string shows it in
              // red under the field and blocks the save.
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                if (value.trim().length > 100) {
                  return 'Keep the title under 100 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Due date + time. Not a TextFormField, so it gets its own
            // manual error display below.
            InkWell(
              onTap: _pickDueDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Due date and time *',
                  prefixIcon: const Icon(Icons.event),
                  errorText: dueMissing ? 'Due date is required' : null,
                ),
                child: Text(
                  _dueDate == null
                      ? 'Tap to choose'
                      : DateFormat('MMM d, y  h:mm a').format(_dueDate!),
                  style: _dueDate == null
                      ? TextStyle(color: theme.hintColor)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Priority', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            // All three options visible at once — fewer taps than a dropdown.
            SegmentedButton<Priority>(
              segments: [
                for (final p in Priority.values)
                  ButtonSegment(
                    value: p,
                    label: Text(p.label),
                    icon: Icon(Icons.flag, color: priorityColor(p), size: 18),
                  ),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<TaskTag>(
              initialValue: _tag,
              decoration: const InputDecoration(
                labelText: 'Tag',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final t in TaskTag.values)
                  DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(tagIcon(t), size: 18),
                        const SizedBox(width: 8),
                        Text(t.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _tag = v ?? TaskTag.others),
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving
                  ? 'Saving...'
                  : (_isEditing ? 'Save changes' : 'Add task')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
