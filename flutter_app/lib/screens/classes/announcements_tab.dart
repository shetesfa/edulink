import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class AnnouncementsTab extends StatefulWidget {
  final int classId;
  const AnnouncementsTab({super.key, required this.classId});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  final _api = ApiClient();
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/classes/${widget.classId}/announcements'));
    if (result.success && result.data != null) {
      final d = result.data!;
      final list = d['data']?['announcements'] ?? d['announcements'] ?? d['data'] ?? [];
      setState(() {
        _announcements = list is List ? list : [];
      });
    }
    setState(() => _isLoading = false);
  }

  void _showCreateDialog() {
    _titleController.clear();
    _contentController.clear();
    bool posting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.campaign_outlined, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text('Post Announcement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Content *',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: posting ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              onPressed: posting
                  ? null
                  : () async {
                      if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          const SnackBar(content: Text('Please fill in title and content')),
                        );
                        return;
                      }
                      setDialogState(() => posting = true);
                      final nav = Navigator.of(dialogCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      final result = await _api.safeCall(
                        () => _api.dio.post('/classes/${widget.classId}/announcements', data: {
                          'title': _titleController.text.trim(),
                          'content': _contentController.text.trim(),
                        }),
                      );
                      if (!mounted) return;
                      if (result.success) {
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Announcement posted successfully.'),
                            backgroundColor: Color(0xFF059669),
                          ),
                        );
                        _load();
                      } else {
                        setDialogState(() => posting = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(result.message),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    },
              child: posting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final auth = context.watch<AuthProvider>();
    final isTeacher = ['teacher', 'school_admin', 'super_admin'].contains(auth.currentUser?.roleName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _announcements.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (isTeacher) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Post First Announcement'),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.campaign_outlined, size: 52, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No announcements yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: _announcements.length + (isTeacher ? 1 : 0),
                itemBuilder: (context, index) {
                  if (isTeacher && index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Post Announcement'),
                      ),
                    );
                  }
                  final ann = _announcements[isTeacher ? index - 1 : index];
                  final isPinned = ann['is_pinned'] == true;
                  final author = ann['author'];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: isPinned ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: isPinned
                          ? const BorderSide(color: Color(0xFF7C3AED), width: 1.5)
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isPinned) ...[
                                const Icon(Icons.push_pin, size: 14, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 4),
                                const Text('Pinned', style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  ann['title'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ann['body'] ?? ann['content'] ?? '',
                            style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                child: Text(
                                  author?['first_name']?.substring(0, 1)?.toUpperCase() ?? 'T',
                                  style: const TextStyle(fontSize: 9, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                author != null ? '${author['first_name']} ${author['last_name']}' : 'Teacher',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              Text(
                                _formatDate(ann['created_at']),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7C3AED),
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add_comment, color: Colors.white),
              label: const Text('Announce', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}
