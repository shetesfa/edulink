import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _api = ApiClient();
  final _searchController = TextEditingController();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/admin/users', queryParameters: {
          if (_searchController.text.isNotEmpty) 'search': _searchController.text,
        }));
    if (result.success && result.data != null) {
      setState(() => _users = result.data!['data']['users']['data']);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleActive(int userId) async {
    final result = await _api.safeCall(() => _api.dio.post('/admin/users/$userId/toggle-active'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    _load();
  }

  Future<void> _changeRole(int userId, String currentRole) async {
    final newRole = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Change role'),
        children: ['student', 'teacher', 'school_admin', 'super_admin']
            .map((r) => SimpleDialogOption(onPressed: () => Navigator.pop(context, r), child: Text(r)))
            .toList(),
      ),
    );
    if (newRole == null) return;

    final result = await _api.safeCall(() => _api.dio.put('/admin/users/$userId/role', data: {'role': newRole}));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    _load();
  }

  Future<void> _deleteUser(int userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _api.safeCall(() => _api.dio.delete('/admin/users/$userId'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search name or email...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final u = _users[index];
                  final isActive = u['is_active'] == true;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive ? null : Colors.grey,
                      child: Text((u['first_name'] as String).isNotEmpty ? u['first_name'][0] : '?'),
                    ),
                    title: Text('${u['first_name']} ${u['last_name']}'),
                    subtitle: Text('${u['email']} • ${u['role']?['name'] ?? ''}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'toggle') _toggleActive(u['id']);
                        if (value == 'role') _changeRole(u['id'], u['role']?['name'] ?? '');
                        if (value == 'delete') _deleteUser(u['id']);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Deactivate' : 'Activate')),
                        const PopupMenuItem(value: 'role', child: Text('Change role')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
