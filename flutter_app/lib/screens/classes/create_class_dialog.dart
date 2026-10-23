import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/class_provider.dart';

class CreateClassDialog extends StatefulWidget {
  const CreateClassDialog({super.key});

  @override
  State<CreateClassDialog> createState() => _CreateClassDialogState();
}

class _CreateClassDialogState extends State<CreateClassDialog> {
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _create() async {
    setState(() => _isLoading = true);
    final result = await context.read<ClassProvider>().createClass(
          name: _nameController.text.trim(),
          subject: _subjectController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a class'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Class name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isLoading ? null : _create,
          child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
        ),
      ],
    );
  }
}
