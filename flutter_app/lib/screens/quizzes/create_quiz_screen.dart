// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class CreateQuizScreen extends StatefulWidget {
  final int classId;
  const CreateQuizScreen({super.key, required this.classId});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _api = ApiClient();
  final _titleController = TextEditingController();
  final _timeLimitController = TextEditingController(text: '30');
  final List<Map<String, dynamic>> _questions = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _timeLimitController.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'question_text': '',
        'question_type': 'multiple_choice',
        'options': ['', '', '', ''],
        'correct_answer': '',
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _updateQuestion(int index, String field, dynamic value) {
    setState(() {
      _questions[index][field] = value;
      // When question type changes, reset answer
      if (field == 'question_type') {
        _questions[index]['correct_answer'] = '';
        if (value == 'multiple_choice') {
          _questions[index]['options'] = ['', '', '', ''];
        }
      }
    });
  }

  String? _validateQuestions() {
    if (_titleController.text.trim().isEmpty) {
      return 'Please enter a quiz title.';
    }
    if (_questions.isEmpty) {
      return 'Please add at least one question.';
    }
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final num = i + 1;
      if (q['question_text'].toString().trim().isEmpty) {
        return 'Question $num: please enter the question text.';
      }
      if (q['question_type'] == 'multiple_choice') {
        final opts = q['options'] as List;
        final filledOpts = opts.where((o) => o.toString().trim().isNotEmpty).toList();
        if (filledOpts.length < 2) {
          return 'Question $num: please fill in at least 2 options.';
        }
        if (q['correct_answer'].toString().isEmpty) {
          return 'Question $num: please select the correct answer (radio button).';
        }
        // Validate selected answer index is in range of filled options
        final idx = int.tryParse(q['correct_answer'].toString());
        if (idx == null || idx >= opts.length || opts[idx].toString().trim().isEmpty) {
          return 'Question $num: the selected correct answer option is empty. Please fill it in.';
        }
      }
      if (q['question_type'] == 'true_false') {
        if (q['correct_answer'].toString().isEmpty) {
          return 'Question $num: please select True or False as the correct answer.';
        }
      }
    }
    return null;
  }

  Future<void> _createQuiz() async {
    final error = _validateQuestions();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Build clean questions payload
    final questionsPayload = _questions.map((q) {
      final clean = <String, dynamic>{
        'question_text': q['question_text'].toString().trim(),
        'question_type': q['question_type'],
        'correct_answer': q['question_type'] == 'multiple_choice'
            ? (q['options'] as List)[int.parse(q['correct_answer'].toString())].toString().trim()
            : q['correct_answer'].toString(),
      };
      if (q['question_type'] == 'multiple_choice') {
        clean['options'] = (q['options'] as List)
            .map((o) => o.toString().trim())
            .where((o) => o.isNotEmpty)
            .toList();
      }
      return clean;
    }).toList();

    final result = await _api.safeCall(() => _api.dio.post('/classes/${widget.classId}/quizzes', data: {
          'title': _titleController.text.trim(),
          'time_limit_minutes': int.tryParse(_timeLimitController.text) ?? 30,
          'questions': questionsPayload,
          'is_published': true,
        }));

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz created and published.'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isTeacher = user?.roleName == 'teacher' || user?.roleName == 'admin' ||
        user?.roleName == 'school_admin' || user?.roleName == 'super_admin';

    if (!isTeacher) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Quiz')),
        body: const Center(child: Text('Only teachers can create quizzes.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('Create Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.25)),
              onPressed: _isLoading ? null : _createQuiz,
              child: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quiz Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF7C3AED))),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Quiz Title *',
                        hintText: 'e.g. Chapter 2 Review Quiz',
                        prefixIcon: const Icon(Icons.quiz_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _timeLimitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Time Limit (minutes)',
                        prefixIcon: const Icon(Icons.timer_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Questions (${_questions.length})',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_questions.isEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.help_outline, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No questions yet.\nTap "Add Question" to start.', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ..._questions.asMap().entries.map((entry) {
              final index = entry.key;
              final q = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE9D5FF), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Q${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Remove question',
                            onPressed: () => _removeQuestion(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Question Text *',
                          hintText: 'Type your question here...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        maxLines: 2,
                        onChanged: (v) => _updateQuestion(index, 'question_text', v),
                      ),
                      const SizedBox(height: 12),
                      // Type picker — only Multiple Choice and True/False
                      Row(
                        children: [
                          Expanded(
                            child: _TypeChip(
                              label: '☑ Multiple Choice',
                              selected: q['question_type'] == 'multiple_choice',
                              onTap: () => _updateQuestion(index, 'question_type', 'multiple_choice'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TypeChip(
                              label: '✓/✗ True / False',
                              selected: q['question_type'] == 'true_false',
                              onTap: () => _updateQuestion(index, 'question_type', 'true_false'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (q['question_type'] == 'multiple_choice') ...[
                        const Text('Options — tap the radio to mark the correct answer:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        ...List.generate(4, (optIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: optIndex.toString(),
                                  groupValue: q['correct_answer'],
                                  activeColor: const Color(0xFF7C3AED),
                                  onChanged: (v) => _updateQuestion(index, 'correct_answer', v),
                                ),
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Option ${optIndex + 1}',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    onChanged: (v) {
                                      final opts = List<String>.from(q['options']);
                                      opts[optIndex] = v;
                                      _updateQuestion(index, 'options', opts);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (q['correct_answer'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF059669), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Correct: Option ${int.parse(q['correct_answer'].toString()) + 1}',
                                  style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                      if (q['question_type'] == 'true_false') ...[
                        const Text('Select the correct answer:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _TFButton(
                                label: '✓ True',
                                selected: q['correct_answer'] == 'True',
                                color: const Color(0xFF059669),
                                onTap: () => _updateQuestion(index, 'correct_answer', 'True'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TFButton(
                                label: '✗ False',
                                selected: q['correct_answer'] == 'False',
                                color: Colors.red.shade600,
                                onTap: () => _updateQuestion(index, 'correct_answer', 'False'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED) : const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF7C3AED), width: selected ? 0 : 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF7C3AED),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _TFButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TFButton({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
