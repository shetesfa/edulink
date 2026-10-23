import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/pdf_report_service.dart';
import '../../providers/auth_provider.dart';

class ProgressTab extends StatefulWidget {
  final int classId;
  final String className;
  const ProgressTab({super.key, required this.classId, required this.className});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  final _api = ApiClient();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/classes/${widget.classId}/progress/me'));
    if (result.success && result.data != null) {
      setState(() => _data = result.data!['data']);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _downloadPdf() async {
    if (_data == null) return;
    setState(() => _isGeneratingPdf = true);

    final studentName = context.read<AuthProvider>().currentUser?.fullName ?? 'Student';
    await PdfReportService.generateAndShare(
      studentName: studentName,
      className: widget.className,
      progress: _data!['progress'],
      completionPercent: _data!['completion_percent'],
    );

    if (mounted) setState(() => _isGeneratingPdf = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_data == null) return const Center(child: Text('No progress data yet.'));

    final progress = _data!['progress'];
    final completion = _data!['completion_percent'] as int;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: completion / 100, strokeWidth: 10),
                Text('$completion%', style: Theme.of(context).textTheme.headlineMedium),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          _statTile('Lessons viewed', '${progress['lessons_viewed']} / ${progress['lessons_total']}', Icons.menu_book),
          _statTile('Assignments submitted', '${progress['assignments_submitted']} / ${progress['assignments_total']}', Icons.assignment_turned_in),
          _statTile('Quizzes taken', '${progress['quizzes_taken']}', Icons.quiz),
          _statTile('Average quiz score', '${progress['avg_quiz_score']}%', Icons.grade),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _isGeneratingPdf ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
            label: const Text('Download PDF report card'),
            onPressed: _isGeneratingPdf ? null : _downloadPdf,
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Card(
      child: ListTile(leading: Icon(icon), title: Text(label), trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
    );
  }
}
