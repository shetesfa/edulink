import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class GroupAssignmentScreen extends StatefulWidget {
  final int assignmentId;
  final String assignmentTitle;
  final int maxGroupSize;

  const GroupAssignmentScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.maxGroupSize,
  });

  @override
  State<GroupAssignmentScreen> createState() => _GroupAssignmentScreenState();
}

class _GroupAssignmentScreenState extends State<GroupAssignmentScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _api.safeCall(() => _api.dio.get('/assignments/${widget.assignmentId}/groups'));
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _groups = List<Map<String, dynamic>>.from(result.data!['data'] ?? []);
        } else {
          _error = result.message;
        }
      });
    }
  }

  Future<void> _createGroup() async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.group_add, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text('Create Group'),
          ],
        ),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'e.g. Team Alpha',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final result = await _api.safeCall(() => _api.dio.post(
          '/assignments/${widget.assignmentId}/groups',
          data: {'name': name},
        ));

    if (mounted) {
      if (result.success) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Group created!'), backgroundColor: Color(0xFF059669)),
        );
        _loadGroups();
      } else {
        messenger.showSnackBar(SnackBar(content: Text(result.message)));
      }
    }
  }

  Future<void> _joinGroup(int groupId) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await _api.safeCall(() => _api.dio.post(
          '/assignments/${widget.assignmentId}/groups/$groupId/join',
        ));

    if (mounted) {
      if (result.success) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Joined group successfully!'), backgroundColor: Color(0xFF059669)),
        );
        _loadGroups();
      } else {
        messenger.showSnackBar(SnackBar(content: Text(result.message)));
      }
    }
  }

  Future<void> _scoreGroup(int groupId, String groupName) async {
    final scoreCtrl = TextEditingController();
    final feedbackCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Grade Group: $groupName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Score (e.g. 25/30)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Feedback (Optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final score = int.tryParse(scoreCtrl.text);
              if (score == null) return;
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final res = await _api.safeCall(() => _api.dio.post(
                    '/assignments/groups/$groupId/score',
                    data: {
                      'score': score,
                      'feedback': feedbackCtrl.text.trim(),
                    },
                  ));
              if (mounted) {
                if (res.success) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Group scored! All members updated.'), backgroundColor: Color(0xFF059669)),
                  );
                  _loadGroups();
                } else {
                  messenger.showSnackBar(SnackBar(content: Text(res.message)));
                }
              }
            },
            child: const Text('Save Score'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isTeacher = user?.roleName == 'teacher' || user?.roleName == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.assignmentTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Group Assignment (Max ${widget.maxGroupSize} members)', style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadGroups),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_error!),
                      TextButton(onPressed: _loadGroups, child: const Text('Retry')),
                    ],
                  ),
                )
              : _groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.groups_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No groups formed yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Create a group or join one below.', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadGroups,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groups.length,
                        itemBuilder: (context, i) {
                          final group = _groups[i];
                          final members = (group['members'] as List<dynamic>? ?? []);
                          final isFull = group['is_full'] == true || members.length >= widget.maxGroupSize;
                          final isMember = members.any((m) => m['user_id'] == user?.id);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.groups, color: Color(0xFF7C3AED)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group['name'] ?? 'Group ${i + 1}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Text(
                                              '${members.length} / ${widget.maxGroupSize} members',
                                              style: TextStyle(color: isFull ? Colors.red : Colors.grey, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isMember)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD1FAE5),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('Your Group', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11)),
                                        )
                                      else if (isFull)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('Full', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
                                        )
                                      else
                                        FilledButton(
                                          onPressed: () => _joinGroup(group['id']),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF7C3AED),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          child: const Text('Join'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Members:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: members.map((m) {
                                      final memberName = m['user']?['first_name'] ?? 'Student';
                                      return Chip(
                                        avatar: CircleAvatar(
                                          child: Text(memberName[0].toUpperCase(), style: const TextStyle(fontSize: 10)),
                                        ),
                                        label: Text(memberName, style: const TextStyle(fontSize: 12)),
                                        visualDensity: VisualDensity.compact,
                                      );
                                    }).toList(),
                                  ),
                                  if (isTeacher) ...[
                                    const Divider(height: 24),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _scoreGroup(group['id'], group['name'] ?? ''),
                                        icon: const Icon(Icons.grade_outlined, size: 16),
                                        label: const Text('Grade All Members'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
