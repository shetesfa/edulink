import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../models/assignment.dart';
import '../../providers/auth_provider.dart';
import 'create_assignment_screen.dart';

class AssignmentsTab extends StatefulWidget {
  final int classId;
  const AssignmentsTab({super.key, required this.classId});

  @override
  State<AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<AssignmentsTab> {
  final _api = ApiClient();
  List<Assignment> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/classes/${widget.classId}/assignments'));
    if (result.success && result.data != null) {
      setState(() {
        _assignments = (result.data!['data']['assignments'] as List).map((a) => Assignment.fromJson(a)).toList();
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isTeacher = user?.roleName == 'teacher' || user?.roleName == 'admin' ||
        user?.roleName == 'school_admin' || user?.roleName == 'super_admin';

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          if (isTeacher)
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => CreateAssignmentScreen(classId: widget.classId)))
                    .then((_) => _load()),
                icon: const Icon(Icons.add),
                label: const Text('Create Assignment'),
              ),
            ),
          Expanded(
            child: _assignments.isEmpty
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.assignment_outlined, size: 52, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No assignments yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                        ],
                      ),
                    )
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _assignments.length,
                    itemBuilder: (context, index) {
                      final a = _assignments[index];
                      final submitted = a.mySubmission != null;
                      final status = a.mySubmission?['status'] as String?;
                      Color statusColor = Colors.grey;
                      IconData statusIcon = Icons.assignment_outlined;
                      if (status == 'graded') {
                        statusColor = const Color(0xFF059669);
                        statusIcon = Icons.check_circle;
                      } else if (submitted) {
                        statusColor = Colors.blue;
                        statusIcon = Icons.send;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => AssignmentDetailScreen(assignmentId: a.id)))
                              .then((_) => _load()),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(isTeacher ? Icons.assignment : statusIcon, color: statusColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 3),
                                      Text(
                                        a.dueDate != null
                                            ? 'Due: ${_formatDue(a.dueDate!)}'
                                            : 'No due date',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      if (!isTeacher && status == 'graded') ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Score: ${a.mySubmission?['score']} / ${a.maxScore}',
                                            style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDue(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.isNegative) return 'Overdue • ${dt.day}/${dt.month}/${dt.year}';
    if (diff.inDays == 0) return 'Today ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Tomorrow';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────
// Assignment Detail — smart view for teacher/student
// ─────────────────────────────────────────────
class AssignmentDetailScreen extends StatefulWidget {
  final int assignmentId;
  const AssignmentDetailScreen({super.key, required this.assignmentId});

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _isTeacher = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/assignments/${widget.assignmentId}'));
    if (result.success && result.data != null) {
      setState(() => _data = result.data!['data']);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    _isTeacher = user?.roleName == 'teacher' || user?.roleName == 'admin' ||
        user?.roleName == 'school_admin' || user?.roleName == 'super_admin';

    final assignment = _data?['assignment'];
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text(assignment?['title'] ?? 'Assignment', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : assignment == null
              ? const Center(child: Text('Could not load assignment.'))
              : _isTeacher
                  ? _TeacherView(data: _data!, onRefresh: _load)
                  : _StudentView(data: _data!, assignmentId: widget.assignmentId, onRefresh: _load),
    );
  }
}

// ─────────────────────────────────────────────
// TEACHER VIEW — see submissions + grade them
// ─────────────────────────────────────────────
class _TeacherView extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;
  const _TeacherView({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final assignment = data['assignment'] as Map<String, dynamic>;
    final submissions = (data['submissions'] as List? ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Assignment info card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    const Text('Assignment Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED), fontSize: 14)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text('Max: ${assignment['max_score'] ?? 100} pts', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(assignment['description'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                if (assignment['due_date'] != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.schedule, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Due: ${assignment['due_date']?.toString().split('T')[0] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Submissions header
        Row(
          children: [
            const Icon(Icons.people, color: Color(0xFF7C3AED), size: 18),
            const SizedBox(width: 6),
            Text('Student Submissions (${submissions.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 10),
        if (submissions.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No submissions yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          ...submissions.map((sub) => _SubmissionCard(
                submission: sub,
                assignment: assignment,
                onGraded: onRefresh,
              )),
      ],
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  final Map<String, dynamic> submission;
  final Map<String, dynamic> assignment;
  final VoidCallback onGraded;
  const _SubmissionCard({required this.submission, required this.assignment, required this.onGraded});

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  final _api = ApiClient();
  final _scoreController = TextEditingController();
  final _feedbackController = TextEditingController();
  bool _expanded = false;
  bool _grading = false;

  @override
  void initState() {
    super.initState();
    final existingScore = widget.submission['score'];
    if (existingScore != null) {
      _scoreController.text = existingScore.toString();
    }
    _feedbackController.text = widget.submission['feedback'] ?? '';
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _grade() async {
    final score = double.tryParse(_scoreController.text.trim());
    if (score == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid score number.')));
      return;
    }
    setState(() => _grading = true);
    final result = await _api.safeCall(() => _api.dio.post(
          '/submissions/${widget.submission['id']}/grade',
          data: {'score': score, 'feedback': _feedbackController.text.trim()},
        ));
    if (!mounted) return;
    setState(() => _grading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.success ? '✅ Graded successfully!' : 'Error: ${result.message}'),
      backgroundColor: result.success ? const Color(0xFF059669) : Colors.red.shade700,
    ));
    if (result.success) widget.onGraded();
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.submission['student'] as Map<String, dynamic>?;
    final status = widget.submission['status'] as String? ?? 'submitted';
    final files = (widget.submission['files'] as List? ?? []);
    final isGraded = status == 'graded';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isGraded ? const Color(0xFF059669) : Colors.grey.shade300, width: isGraded ? 1.5 : 1),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    child: Text(
                      student?['first_name']?.substring(0, 1).toUpperCase() ?? 'S',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${student?['first_name'] ?? ''} ${student?['last_name'] ?? ''}'.trim(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          isGraded
                              ? 'Score: ${widget.submission['score']} / ${widget.assignment['max_score'] ?? 100}'
                              : 'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isGraded ? const Color(0xFF059669) : Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isGraded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${widget.submission['score']}/${widget.assignment['max_score'] ?? 100}',
                        style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.submission['text_answer'] != null && widget.submission['text_answer'].toString().isNotEmpty) ...[
                    const Text('📝 Written Answer:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(widget.submission['text_answer'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (files.isNotEmpty) ...[
                    const Text('📎 Attached Files:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    ...files.map((f) => _FileRow(file: f)),
                    const SizedBox(height: 12),
                  ],
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('✏️ Grade This Submission:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7C3AED))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _scoreController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Score',
                            hintText: '0 – ${widget.assignment['max_score'] ?? 100}',
                            prefixIcon: const Icon(Icons.grade_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('/ ${widget.assignment['max_score'] ?? 100}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Feedback (optional)',
                      prefixIcon: const Icon(Icons.comment_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                      onPressed: _grading ? null : _grade,
                      icon: _grading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(isGraded ? 'Update Grade' : 'Save Grade'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STUDENT VIEW — submit + see graded result
// ─────────────────────────────────────────────
class _StudentView extends StatefulWidget {
  final Map<String, dynamic> data;
  final int assignmentId;
  final VoidCallback onRefresh;
  const _StudentView({required this.data, required this.assignmentId, required this.onRefresh});

  @override
  State<_StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends State<_StudentView> {
  final _api = ApiClient();
  final _answerController = TextEditingController();
  bool _isSubmitting = false;
  String? _attachedFileName;
  String? _attachedFilePath;

  @override
  void initState() {
    super.initState();
    // Pre-fill if already submitted
    final sub = widget.data['my_submission'];
    if (sub != null) {
      _answerController.text = sub['text_answer'] ?? '';
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _attachedFilePath = result.files.single.path;
        _attachedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final formMap = <String, dynamic>{'text_answer': _answerController.text};
    if (_attachedFilePath != null) {
      formMap['attachments[]'] = await MultipartFile.fromFile(_attachedFilePath!, filename: _attachedFileName);
    }
    final result = await _api.safeCall(() => _api.dio.post(
          '/assignments/${widget.assignmentId}/submit',
          data: FormData.fromMap(formMap),
        ));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.success ? '✅ Submitted successfully!' : 'Error: ${result.message}'),
      backgroundColor: result.success ? const Color(0xFF059669) : Colors.red.shade700,
    ));
    if (result.success) widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.data['assignment'] as Map<String, dynamic>;
    final mySubmission = widget.data['my_submission'] as Map<String, dynamic>?;
    final isGraded = mySubmission?['status'] == 'graded';
    final submittedFiles = (mySubmission?['files'] as List? ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Assignment description
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.assignment, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Assignment', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)))),
                  if (assignment['max_score'] != null)
                    Text('${assignment['max_score']} pts', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
                const SizedBox(height: 10),
                Text(assignment['description'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                if (assignment['due_date'] != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.schedule, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Due: ${assignment['due_date']?.toString().split('T')[0] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // GRADED result card
        if (isGraded) ...[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF059669), width: 1.5)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 8),
                    Text('Your Grade', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 15)),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${mySubmission!['score']}',
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                            ),
                            Text('out of ${assignment['max_score'] ?? 100}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${((mySubmission['score'] ?? 0) / (assignment['max_score'] ?? 100) * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                            ),
                            const Text('Percentage', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (mySubmission['feedback'] != null && mySubmission['feedback'].toString().isNotEmpty) ...[
                    const Divider(height: 20),
                    const Text('Teacher Feedback:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(mySubmission['feedback'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Already submitted but not graded
        if (mySubmission != null && !isGraded) ...[
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.send, color: Colors.blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Submitted — Awaiting Grade', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                        if (mySubmission['submitted_at'] != null)
                          Text('Submitted: ${mySubmission['submitted_at'].toString().split('T')[0]}',
                              style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Show previously submitted files
          if (submittedFiles.isNotEmpty) ...[
            const Text('📎 Your Submitted Files:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...submittedFiles.map((f) => _FileRow(file: f)),
            const SizedBox(height: 12),
          ],
        ],

        // Submission form — always shown so student can resubmit
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mySubmission != null ? '✏️ Edit & Resubmit' : '✏️ Your Answer',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _answerController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Write your answer here...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  icon: const Icon(Icons.attach_file, color: Color(0xFF7C3AED)),
                  label: Text(
                    _attachedFileName ?? 'Attach a file (PDF, Word, image…)',
                    style: const TextStyle(color: Color(0xFF7C3AED)),
                  ),
                  onPressed: _pickFile,
                ),
                if (_attachedFileName != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(_attachedFileName!, style: const TextStyle(fontSize: 12, color: Color(0xFF059669)))),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.red),
                      onPressed: () => setState(() { _attachedFileName = null; _attachedFilePath = null; }),
                    ),
                  ]),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), minimumSize: const Size(double.infinity, 48)),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: Text(mySubmission != null ? 'Resubmit' : 'Submit Assignment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// File row widget — open or download a file
// ─────────────────────────────────────────────
class _FileRow extends StatelessWidget {
  final Map<String, dynamic> file;
  const _FileRow({required this.file});

  IconData _iconForExt(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': case 'docx': return Icons.description;
      case 'ppt': case 'pptx': return Icons.slideshow;
      case 'xls': case 'xlsx': return Icons.table_chart;
      case 'jpg': case 'jpeg': case 'png': return Icons.image;
      default: return Icons.insert_drive_file;
    }
  }

  Future<void> _open(BuildContext context) async {
    final rawUrl = file['url'] ?? file['file_url'] ?? file['path'];
    final url = ApiConfig.resolveMediaUrl(rawUrl?.toString());
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open this file.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = file['original_name'] ?? file['name'] ?? 'File';
    final ext = name.contains('.') ? name.split('.').last : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        leading: Icon(_iconForExt(ext), color: const Color(0xFF7C3AED), size: 22),
        title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18, color: Color(0xFF7C3AED)),
              tooltip: 'Open',
              onPressed: () => _open(context),
            ),
            IconButton(
              icon: const Icon(Icons.download, size: 18, color: Color(0xFF059669)),
              tooltip: 'Download',
              onPressed: () => _open(context),
            ),
          ],
        ),
      ),
    );
  }
}
