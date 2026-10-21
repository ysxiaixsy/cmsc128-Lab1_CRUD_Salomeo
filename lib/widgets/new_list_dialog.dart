import 'package:flutter/material.dart';

import '../logic/validators.dart';

/// Asks for a name for a new shared list.
///
/// Returns the trimmed name, or null if the user cancelled.
Future<String?> showNewListDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _NewListDialog(),
  );
}

class _NewListDialog extends StatefulWidget {
  const _NewListDialog();

  @override
  State<_NewListDialog> createState() => _NewListDialogState();
}

class _NewListDialogState extends State<_NewListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _create() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.group_add_outlined),
      title: const Text('New shared list'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: kMaxListNameLength,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _create(),
          validator: validateListName,
          decoration: const InputDecoration(
            labelText: 'List name',
            hintText: "e.g. JP's Group List",
            helperText: 'You can add members after creating it',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
