import 'dart:async';
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../models/quiz.dart';
import '../../providers/auth_provider.dart';
import 'create_quiz_screen.dart';

class QuizzesTab extends StatefulWidget {
  final int classId;
  const QuizzesTab({super.key, required this.classId});

  @override
  State<QuizzesTab> createState() => _QuizzesTabState();
}

class _QuizzesTabState extends State<QuizzesTab> {
  final _api = ApiClient();
  List<Quiz> _quizzes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/classes/${widget.classId}/quizzes'));
    if (result.success && result.data != null) {
      final quizList = result.data!['quizzes'] ?? result.data!['data']?['quizzes'];
      if (quizList is List) {
        setState(() {
          _quizzes = quizList.map((q) => Quiz.fromJson(q)).toList();
        });
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isTeacher = ['teacher', 'school_admin', 'super_admin'].contains(user?.roleName);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          if (isTeacher)
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => CreateQuizScreen(classId: widget.classId)))
                    .then((_) => _load()),
                icon: const Icon(Icons.add),
                label: const Text('Create Quiz'),
              ),
            ),
          Expanded(
            child: _quizzes.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No quizzes yet.')))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _quizzes.length,
                    itemBuilder: (context, index) {
                      final q = _quizzes[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.quiz, color: Color(0xFF7C3AED)),
                          title: Text(q.title),
                          subtitle: Text('${q.questionsCount} questions${q.timeLimitMinutes != null ? ' • ${q.timeLimitMinutes} min' : ''}'),
                          trailing: isTeacher
                              ? const Chip(
                                  avatar: Icon(Icons.bar_chart, size: 14),
                                  label: Text('Results', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                )
                              : const Icon(Icons.play_arrow, color: Colors.green),
                          onTap: () {
                            if (isTeacher) {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => TeacherQuizAnalyticsScreen(quizId: q.id)),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => TakeQuizScreen(quizId: q.id, timeLimitMinutes: q.timeLimitMinutes)),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TeacherQuizAnalyticsScreen extends StatefulWidget {
  final int quizId;
  const TeacherQuizAnalyticsScreen({super.key, required this.quizId});

  @override
  State<TeacherQuizAnalyticsScreen> createState() => _TeacherQuizAnalyticsScreenState();
}

class _TeacherQuizAnalyticsScreenState extends State<TeacherQuizAnalyticsScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _api.safeCall(() => _api.dio.get('/quizzes/${widget.quizId}/analytics'));
    if (result.success && result.data != null) {
      setState(() => _analytics = result.data!['data'] ?? result.data);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final attempts = (_analytics?['attempts'] as List? ?? []);
    final stats = _analytics?['stats'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results & Student Scores')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('${stats['total_attempts'] ?? attempts.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text('Attempts', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('${stats['average_score'] ?? 0}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const Text('Avg Score', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('${stats['pass_rate'] ?? 0}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                      const Text('Pass Rate', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Student Results (${attempts.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          attempts.isEmpty
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No student submissions yet.')))
              : Column(
                  children: attempts.map((att) {
                    final student = att['student'];
                    final score = att['score'];
                    final passed = att['passed'] == true || (score is num && score >= 50);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: passed ? Colors.green.shade100 : Colors.orange.shade100,
                          child: Icon(passed ? Icons.check : Icons.priority_high, color: passed ? Colors.green : Colors.orange),
                        ),
                        title: Text(student != null ? '${student['first_name']} ${student['last_name']}' : 'Student #${att['user_id']}'),
                        subtitle: Text('Score: ${score ?? 0}%'),
                        trailing: Text(
                          passed ? 'PASSED' : 'FAILED',
                          style: TextStyle(fontWeight: FontWeight.bold, color: passed ? Colors.green : Colors.red),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}

class TakeQuizScreen extends StatefulWidget {
  final int quizId;
  final int? timeLimitMinutes;
  const TakeQuizScreen({super.key, required this.quizId, this.timeLimitMinutes});

  @override
  State<TakeQuizScreen> createState() => _TakeQuizScreenState();
}

class _TakeQuizScreenState extends State<TakeQuizScreen> {
  final _api = ApiClient();
  List<dynamic> _questions = [];
  final Map<int, String> _answers = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _result;
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.timeLimitMinutes != null) {
      _remainingSeconds = widget.timeLimitMinutes! * 60;
      _startTimer();
    }
    _load();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        if (!_isSubmitting && _result == null) {
          _submit();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time is up! Auto-submitting...')));
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await _api.safeCall(() => _api.dio.get('/quizzes/${widget.quizId}/take'));
    if (result.success && result.data != null) {
      setState(() => _questions = result.data!['questions'] ?? result.data!['data']?['questions'] ?? []);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final result = await _api.safeCall(() => _api.dio.post('/quizzes/${widget.quizId}/submit', data: {
          'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        }));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result.success) {
      setState(() => _result = result.data!['data'] ?? result.data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_result != null) {
      final percentage = _result!['percentage'] ?? _result!['score'];
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                (_result!['passed'] == true) ? Icons.emoji_events : Icons.info,
                size: 64,
                color: (_result!['passed'] == true) ? Colors.amber : Colors.blueGrey,
              ),
              const SizedBox(height: 12),
              Text(percentage != null ? '$percentage%' : 'Submitted', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(_result!['message_detail'] ?? 'Quiz submitted successfully!'),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Quiz'),
        actions: [
          if (widget.timeLimitMinutes != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent),
                ),
              ),
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final q = _questions[index];
          final qId = (q['id'] as num).toInt();
          final opts = q['options'] is List ? List<String>.from(q['options']) : null;
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${index + 1}. ${q['question_text']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (q['question_type'] == 'listening') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.headphones, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q['audio_url'] != null ? 'Audio Clip: ${q['audio_url']}' : 'Audio question clip',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill, color: Color(0xFF7C3AED), size: 32),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Playing audio question clip...')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Type your answer or speak',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.mic, color: Color(0xFF7C3AED)),
                          tooltip: 'Voice Input',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Listening to voice input... (Speak now)')),
                            );
                          },
                        ),
                      ),
                      onChanged: (v) => _answers[qId] = v,
                    ),
                  ] else if (q['question_type'] == 'essay')
                    TextField(
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Your answer', border: OutlineInputBorder()),
                      onChanged: (v) => _answers[qId] = v,
                    )
                  else if (opts != null)
                    ...opts.map((option) => RadioListTile<String>(
                          title: Text(option),
                          value: option,
                          groupValue: _answers[qId],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _answers[qId] = v);
                            }
                          },
                        ))
                  else
                    TextField(
                      decoration: const InputDecoration(hintText: 'Fill in the blank', border: OutlineInputBorder()),
                      onChanged: (v) => _answers[qId] = v,
                    ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit Quiz'),
          ),
        ),
      ),
    );
  }
}
