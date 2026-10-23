import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen> {
  final _api = ApiClient();
  List<dynamic> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/admin/classes'));
    if (result.success && result.data != null) {
      setState(() => _classes = result.data!['data']['classes']['data']);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleActive(int classId) async {
    final result = await _api.safeCall(() => _api.dio.post('/admin/classes/$classId/toggle-active'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class Moderation')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _classes.length,
                itemBuilder: (context, index) {
                  final c = _classes[index];
                  final isActive = c['is_active'] == true;
                  return ListTile(
                    leading: Icon(Icons.class_, color: isActive ? Colors.deepPurple : Colors.grey),
                    title: Text(c['name']),
                    subtitle: Text('${c['teacher']?['first_name'] ?? ''} ${c['teacher']?['last_name'] ?? ''} • ${c['students_count']} students'),
                    trailing: Switch(value: isActive, onChanged: (_) => _toggleActive(c['id'])),
                  );
                },
              ),
            ),
    );
  }
}
