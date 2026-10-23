import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class StudentsTab extends StatefulWidget {
  final int classId;
  const StudentsTab({super.key, required this.classId});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final _api = ApiClient();
  List<dynamic> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/classes/${widget.classId}/students'));
    if (result.success && result.data != null) {
      setState(() {
        _students = result.data!['data']['students'] as List;
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: _students.isEmpty
          ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No students enrolled yet.')))])
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (student['first_name'] ?? '')[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'),
                    subtitle: Text(student['email'] ?? ''),
                    trailing: student['is_leader'] == true
                        ? const Chip(
                            label: Text('Leader', style: TextStyle(fontSize: 12)),
                            backgroundColor: Colors.amber,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
