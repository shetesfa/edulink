import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final _api = ApiClient();
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/admin/audit-logs'));
    if (result.success && result.data != null) {
      setState(() => _logs = result.data!['data']['logs']['data']);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  final actor = log['user'] != null ? '${log['user']['first_name']} ${log['user']['last_name']}' : 'System';
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(log['action']),
                    subtitle: Text('$actor • ${log['ip_address'] ?? ''}'),
                    trailing: Text(log['created_at'].toString().split('T')[0]),
                  );
                },
              ),
            ),
    );
  }
}
