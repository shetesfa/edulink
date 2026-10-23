import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _api = ApiClient();
  List<dynamic> _meetings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/meetings'));
    if (result.success && result.data != null) {
      setState(() => _meetings = result.data!['data']['meetings']);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _joinMeeting(int meetingId) async {
    final result = await _api.safeCall(() => _api.dio.get('/meetings/$meetingId/token'));
    if (!mounted) return;

    if (result.success) {
      final join = result.data!['data']['join'];
      final url = Uri.parse(join['meeting_url']);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meetings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _meetings.isEmpty
                  ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No meetings scheduled.')))])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _meetings.length,
                      itemBuilder: (context, index) {
                        final m = _meetings[index];
                        final isLive = m['status'] == 'live';
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.videocam, color: isLive ? Colors.red : null),
                            title: Text(m['title']),
                            subtitle: Text(isLive ? 'Live now' : (m['status'] == 'ended' ? 'Ended' : 'Scheduled')),
                            trailing: m['status'] != 'ended'
                                ? FilledButton(onPressed: () => _joinMeeting(m['id']), child: const Text('Join'))
                                : null,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
