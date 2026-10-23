import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'study_room_chat_screen.dart';

class StudyRoomsScreen extends StatefulWidget {
  const StudyRoomsScreen({super.key});

  @override
  State<StudyRoomsScreen> createState() => _StudyRoomsScreenState();
}

class _StudyRoomsScreenState extends State<StudyRoomsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    final result = await _api.safeCall(() => _api.dio.get('/study-rooms'));
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          final data = result.data!['data'];
          if (data is Map) {
            final joined = List<Map<String, dynamic>>.from(data['joined_rooms'] ?? []);
            final publicList = List<Map<String, dynamic>>.from(data['public_rooms'] ?? []);

            for (var r in joined) {
              r['is_member'] = true;
            }
            for (var r in publicList) {
              r['is_member'] = joined.any((j) => j['id'] == r['id']);
            }

            final combined = <int, Map<String, dynamic>>{};
            for (var r in joined) {
              combined[r['id'] as int] = r;
            }
            for (var r in publicList) {
              if (!combined.containsKey(r['id'])) {
                combined[r['id'] as int] = r;
              }
            }

            _rooms = combined.values.toList();
          } else if (data is List) {
            _rooms = List<Map<String, dynamic>>.from(data);
          }
        } else {
          _error = result.message;
        }
      });
    }
  }

  Future<void> _joinByCode() async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Text('🚪 ', style: TextStyle(fontSize: 24)), Text('Join by Code')]),
        content: TextField(
          controller: codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Study Room Code', hintText: 'e.g. ABC123', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, codeController.text.trim().toUpperCase()), child: const Text('Join')),
        ],
      ),
    );

    if (code == null || code.isEmpty) return;
    final result = await _api.safeCall(() => _api.dio.post('/study-rooms/join', data: {'join_code': code}));
    if (mounted) {
      if (result.success) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined study room!'), backgroundColor: Color(0xFF059669)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
    }
  }

  Future<void> _createRoom() async {
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Text('📚 ', style: TextStyle(fontSize: 22)), Text('Create Study Room')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Room Name *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject (optional)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final result = await _api.safeCall(() => _api.dio.post('/study-rooms', data: {
                'name': nameCtrl.text.trim(),
                'subject': subjectCtrl.text.trim().isEmpty ? null : subjectCtrl.text.trim(),
                'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              }));
              if (mounted) {
                if (result.success) {
                  _load();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Study Rooms', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.vpn_key_outlined), tooltip: 'Join by code', onPressed: _joinByCode),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: 'My Rooms'), Tab(text: 'Public Rooms')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRoom,
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Room'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRoomsList(_rooms.where((r) => r['is_member'] == true).toList()),
                    _buildRoomsList(_rooms.where((r) => r['is_public'] == true).toList()),
                  ],
                ),
    );
  }

  Widget _buildRoomsList(List<Map<String, dynamic>> rooms) {
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📚', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('No study rooms yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Create one or join with a code', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rooms.length,
        itemBuilder: (context, i) {
          final room = rooms[i];
          final subject = room['subject'] as String?;
          final memberCount = room['member_count'] as int? ?? 0;
          final isMember = room['is_member'] as bool? ?? false;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StudyRoomChatScreen(roomId: room['id'] as int, roomName: room['name'] as String)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.groups_2_outlined, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(room['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          if (subject != null) ...[
                            const SizedBox(height: 2),
                            Text(subject, style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.people_outline, size: 13, color: Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Text('$memberCount members', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Code: ${room["join_code"] ?? ""}', style: const TextStyle(fontSize: 10, color: Color(0xFF0369A1), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isMember)
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF7C3AED))
                    else
                      TextButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final r = await _api.safeCall(() => _api.dio.post('/study-rooms/join', data: {'join_code': room['join_code']}));
                          if (mounted) {
                            if (r.success) { _load(); } else { messenger.showSnackBar(SnackBar(content: Text(r.message))); }
                          }
                        },
                        child: const Text('Join'),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
