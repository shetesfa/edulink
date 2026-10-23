import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class TeacherAnalyticsScreen extends StatefulWidget {
  final int classId;
  final String className;
  const TeacherAnalyticsScreen({super.key, required this.classId, required this.className});

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all';

  static const _statusConfig = {
    'excellent': (Color(0xFF059669), Color(0xFFD1FAE5), Icons.star_rounded, '⭐ Excellent'),
    'struggling': (Color(0xFFDC2626), Color(0xFFFEE2E2), Icons.warning_rounded, '⚠️ Struggling'),
    'declining': (Color(0xFFD97706), Color(0xFFFEF3C7), Icons.trending_down_rounded, '📉 Declining'),
    'first_time_low': (Color(0xFF2563EB), Color(0xFFDBEAFE), Icons.info_rounded, '🔵 First Low'),
    'normal': (Color(0xFF6B7280), Color(0xFFF3F4F6), Icons.check_circle_outline, '✅ Normal'),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    final result = await _api.safeCall(() => _api.dio.get('/analytics/class/${widget.classId}'));
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _students = List<Map<String, dynamic>>.from(result.data!['data'] ?? []);
        } else {
          _error = result.message;
        }
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _students;
    return _students.where((s) => s['performance_status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Student Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.className, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
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
              : Column(
                  children: [
                    _buildSummaryCards(),
                    _buildFilterBar(),
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(child: Text('No students match this filter'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) => _buildStudentCard(_filtered[i]),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryCards() {
    final statusCounts = <String, int>{};
    for (final s in _students) {
      final status = s['performance_status'] as String? ?? 'normal';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Class Overview — ${_students.length} students', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusConfig.entries.map((e) {
                final count = statusCounts[e.key] ?? 0;
                final cfg = e.value;
                return GestureDetector(
                  onTap: () => setState(() => _filter = e.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _filter == e.key ? cfg.$1 : cfg.$2,
                      borderRadius: BorderRadius.circular(12),
                      border: _filter == e.key ? Border.all(color: cfg.$1, width: 2) : null,
                    ),
                    child: Column(
                      children: [
                        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _filter == e.key ? Colors.white : cfg.$1)),
                        Text(cfg.$4.split(' ').last, style: TextStyle(fontSize: 11, color: _filter == e.key ? Colors.white : cfg.$1, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
          GestureDetector(
            onTap: () => setState(() => _filter = 'all'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _filter == 'all' ? const Color(0xFF7C3AED) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('All (${_students.length})',
                  style: TextStyle(color: _filter == 'all' ? Colors.white : const Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final status = student['performance_status'] as String? ?? 'normal';
    final cfg = _statusConfig[status] ?? _statusConfig['normal']!;
    final name = student['name'] as String? ?? 'Student';
    final avgScore = (student['avg_quiz_score'] as num?)?.toDouble() ?? 0.0;
    final quizCount = student['quiz_count'] as int? ?? 0;
    final assignmentCount = student['assignment_count'] as int? ?? 0;
    final suggestion = student['suggestion'] as String? ?? '';
    final recentScores = (student['recent_scores'] as List<dynamic>? ?? []).cast<int>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cfg.$1.withValues(alpha: 0.15),
                  child: Text(name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: cfg.$1, fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('$quizCount quizzes · $assignmentCount assignments', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: cfg.$2, borderRadius: BorderRadius.circular(20)),
                  child: Text(cfg.$4, style: TextStyle(fontSize: 11, color: cfg.$1, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildScoreBadge('Avg Score', '${avgScore.toStringAsFixed(0)}%', cfg.$1),
                const SizedBox(width: 12),
                if (recentScores.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recent Scores', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        const SizedBox(height: 4),
                        Row(
                          children: recentScores.take(5).map((s) {
                            final c = s >= 80 ? const Color(0xFF059669) : s >= 60 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
                            return Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text('$s%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (suggestion.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: cfg.$2, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(cfg.$3, size: 16, color: cfg.$1),
                    const SizedBox(width: 8),
                    Expanded(child: Text(suggestion, style: TextStyle(fontSize: 12, color: cfg.$1, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (status == 'struggling' || status == 'declining')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sendSupportMessage(student),
                      icon: const Icon(Icons.message_outlined, size: 14),
                      label: const Text('Send Support', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cfg.$1,
                        side: BorderSide(color: cfg.$1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                if (status == 'excellent')
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _sendAppreciation(student),
                      icon: const Icon(Icons.thumb_up_outlined, size: 14),
                      label: const Text('Send Appreciation', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: cfg.$1,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Future<void> _sendSupportMessage(Map<String, dynamic> student) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Support message sent to ${student["name"]}'),
        backgroundColor: const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _sendAppreciation(Map<String, dynamic> student) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appreciation sent to ${student["name"]} ⭐'),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
