import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _api = ApiClient();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _create() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.post('/chat/groups', data: {
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
        }));
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create group'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Group name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder())),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isLoading ? null : _create,
          child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
        ),
      ],
    );
  }
}
