import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';

class GroupInfoScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String? joinCode;
  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.joinCode,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _api = ApiClient();
  List<dynamic> _members = [];
  bool _isLoading = true;
  String? _groupJoinCode;

  @override
  void initState() {
    super.initState();
    _groupJoinCode = widget.joinCode;
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/chat/groups/${widget.groupId}/members'));
    if (result.success && result.data != null) {
      setState(() {
        _members = result.data!['data']['members'] ?? [];
        if (result.data!['data']['group'] != null && result.data!['data']['group']['join_code'] != null) {
          _groupJoinCode = result.data!['data']['group']['join_code'];
        }
      });
    }
    setState(() => _isLoading = false);
  }

  void _copyJoinCode() {
    final code = _groupJoinCode ?? 'GRP-${widget.groupId}';
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group invite code "$code" copied to clipboard!')),
    );
  }

  Future<void> _removeMember(int userId) async {
    final result = await _api.safeCall(() => _api.dio.delete('/chat/groups/${widget.groupId}/members/$userId'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    _load();
  }

  Future<void> _leaveGroup() async {
    final result = await _api.safeCall(() => _api.dio.post('/chat/groups/${widget.groupId}/leave'));
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: ListTile(
                    leading: const Icon(Icons.share, color: Color(0xFF7C3AED)),
                    title: const Text('Invite Members to Group', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Invite Code: ${_groupJoinCode ?? "Tap to view & copy"}'),
                    trailing: const Icon(Icons.copy, size: 20),
                    onTap: _copyJoinCode,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('Members (${_members.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                ..._members.map((m) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text('${m['first_name']} ${m['last_name']}'),
                      subtitle: Text(m['pivot']?['role'] ?? 'member'),
                      trailing: m['pivot']?['role'] != 'owner'
                          ? IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _removeMember(m['id']))
                          : null,
                    )),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text('Leave group', style: TextStyle(color: Colors.red)),
                  onTap: _leaveGroup,
                ),
              ],
            ),
    );
  }
}
