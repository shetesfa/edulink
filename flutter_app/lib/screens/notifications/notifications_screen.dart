import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiClient();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/notifications'));
    if (result.success && result.data != null) {
      setState(() => _notifications = result.data!['data']['notifications']['data']);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _markAllRead() async {
    await _api.safeCall(() => _api.dio.post('/notifications/read-all'));
    _load();
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'megaphone':
        return Icons.campaign;
      case 'clipboard':
        return Icons.assignment;
      case 'help-circle':
        return Icons.quiz;
      case 'check-circle':
        return Icons.check_circle;
      case 'video':
        return Icons.videocam;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [TextButton(onPressed: _markAllRead, child: const Text('Mark all read'))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No notifications yet.')))])
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        return ListTile(
                          leading: Icon(_iconFor(n['icon'] ?? 'bell'), color: n['is_read'] == true ? Colors.grey : Colors.deepPurple),
                          title: Text(n['title'], style: TextStyle(fontWeight: n['is_read'] == true ? FontWeight.normal : FontWeight.bold)),
                          subtitle: Text(n['body'] ?? ''),
                          onTap: () async {
                            await _api.safeCall(() => _api.dio.post('/notifications/${n['id']}/read'));
                            _load();
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
