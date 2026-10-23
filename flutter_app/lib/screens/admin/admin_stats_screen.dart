import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/admin/stats'));
    if (result.success && result.data != null) {
      setState(() => _stats = result.data!['data']);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Statistics')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _stats == null
                  ? const Center(child: Text('Failed to load statistics'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatCard('Total Users', _stats!['total_users']?.toString() ?? '0', Icons.people, Colors.blue),
                          _buildStatCard('Active Classes', _stats!['active_classes']?.toString() ?? '0', Icons.class_, Colors.purple),
                          _buildStatCard('Total Assignments', _stats!['total_assignments']?.toString() ?? '0', Icons.assignment, Colors.orange),
                          _buildStatCard('Total Quizzes', _stats!['total_quizzes']?.toString() ?? '0', Icons.quiz, Colors.green),
                          _buildStatCard('AI Requests Today', _stats!['ai_requests_today']?.toString() ?? '0', Icons.psychology, Colors.pink),
                          const SizedBox(height: 24),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('User Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  _buildDistributionRow('Students', _stats!['students'] ?? 0, Colors.blue),
                                  _buildDistributionRow('Teachers', _stats!['teachers'] ?? 0, Colors.green),
                                  _buildDistributionRow('Admins', _stats!['admins'] ?? 0, Colors.purple),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
