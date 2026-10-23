import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class CreateAssignmentScreen extends StatefulWidget {
  final int classId;
  const CreateAssignmentScreen({super.key, required this.classId});

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _api = ApiClient();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxScoreController = TextEditingController(text: '100');
  DateTime? _dueDate;
  bool _isLoading = false;

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 23, minute: 59),
      );
      if (time != null && mounted) {
        setState(() {
          _dueDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  String _type = 'individual';
  final _maxGroupSizeController = TextEditingController(text: '4');
  DateTime? _startDate;

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null && mounted) {
        setState(() {
          _startDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createAssignment() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _api.safeCall(() => _api.dio.post('/classes/${widget.classId}/assignments', data: {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'max_score': int.tryParse(_maxScoreController.text) ?? 100,
      'due_date': _dueDate?.toIso8601String(),
      'type': _type,
      'max_group_size': int.tryParse(_maxGroupSizeController.text) ?? 4,
      'start_at': _startDate?.toIso8601String(),
    }));

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment created successfully!')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isTeacher = user?.roleName == 'teacher' || user?.roleName == 'admin' ||
        user?.roleName == 'school_admin' || user?.roleName == 'super_admin';

    if (!isTeacher) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Assignment')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Only teachers can create assignments.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Assignment'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createAssignment,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Assignment Title *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Assignment Type Toggle
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'individual',
                  label: Text('Individual'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: 'group',
                  label: Text('Group Assignment'),
                  icon: Icon(Icons.groups),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (Set<String> selection) {
                setState(() => _type = selection.first);
              },
            ),
            if (_type == 'group') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _maxGroupSizeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Group Size',
                  hintText: 'e.g. 4 members',
                  prefixIcon: Icon(Icons.group_add),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _maxScoreController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum Score',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectStartDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start / Schedule Date (Optional)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.schedule),
                ),
                child: Text(
                  _startDate != null
                      ? '${_startDate!.toLocal()}'.split('.')[0]
                      : 'Immediate Start (Default)',
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDueDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _dueDate != null
                      ? '${_dueDate!.toLocal()}'.split('.')[0]
                      : 'No due date selected',
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Note: For group assignments, one submission from any group member applies to all group members.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

