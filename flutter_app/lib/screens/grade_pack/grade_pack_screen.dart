import 'package:flutter/material.dart';
import '../../core/api_client.dart';

const _purple  = Color(0xFF7C3AED);
const _purpleL = Color(0xFFA855F7);
const _dark    = Color(0xFF060612);
const _card    = Color(0xFF0F0F24);
const _card2   = Color(0xFF111127);
const _text1   = Color(0xFFE5E7EB);
const _text2   = Color(0xFF9CA3AF);
const _border  = Color(0xFF1F1F3A);
const _green   = Color(0xFF10B981);
const _red     = Color(0xFFEF4444);

class GradePackScreen extends StatefulWidget {
  const GradePackScreen({super.key});

  @override
  State<GradePackScreen> createState() => _GradePackScreenState();
}

class _GradePackScreenState extends State<GradePackScreen> {
  final _api = ApiClient();
  bool _loading = false;
  List<Map<String, dynamic>> _packs = [];
  int _selectedGrade = 9;
  String _selectedSubject = 'mathematics';
  List<Map<String, dynamic>> _units = [];
  Map<String, dynamic>? _activeUnitData;
  bool _loadingUnit = false;

  final List<String> _subjects = [
    'mathematics', 'biology', 'chemistry', 'physics',
    'english', 'history', 'geography', 'economics',
    'civics', 'information_technology'
  ];

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  Future<void> _loadPacks() async {
    setState(() => _loading = true);
    final res = await _api.safeCall(() => _api.dio.get('/grade-packs'));
    if (res.success && res.data != null) {
      final list = (res.data!['packs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _packs = list;
        _loading = false;
      });
      if (_packs.isNotEmpty) {
        _loadSubjectUnits();
      } else {
        // Auto import local default pack if not installed
        _importPack();
      }
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _importPack([String? path]) async {
    setState(() => _loading = true);
    final res = await _api.safeCall(() => _api.dio.post('/grade-packs/import', data: {
      if (path != null) 'path': path,
    }));
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.data?['message'] ?? 'Grade Pack imported successfully!'), backgroundColor: _green),
      );
      _loadPacks();
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message.isNotEmpty ? res.message : 'Import failed.'), backgroundColor: _red),
      );
    }
  }

  Future<void> _loadSubjectUnits() async {
    setState(() => _loadingUnit = true);
    final res = await _api.safeCall(() => _api.dio.get('/grade-packs/$_selectedGrade/$_selectedSubject/units'));
    if (res.success && res.data != null) {
      final list = (res.data!['units'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _units = list;
        _loadingUnit = false;
      });
    } else {
      setState(() {
        _units = [];
        _loadingUnit = false;
      });
    }
  }

  Future<void> _openUnitStudy(int unitNum) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _purpleL)),
    );

    final res = await _api.safeCall(() => _api.dio.get('/grade-packs/$_selectedGrade/$_selectedSubject/unit/$unitNum'));
    Navigator.of(context).pop();

    if (res.success && res.data != null) {
      _showUnitDetailModal(res.data!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load unit content.'), backgroundColor: _red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        title: const Row(children: [
          Text('📦 ', style: TextStyle(fontSize: 18)),
          Text('Offline Grade Packs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text1)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: _purpleL),
            tooltip: 'Import Grade Pack ZIP',
            onPressed: () => _importPack(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _text2),
            onPressed: _loadPacks,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Installed Pack Header Card
              _buildPackHeader(),
              // ── Subject Selector Bar
              _buildSubjectSelector(),
              // ── Unit List
              Expanded(child: _buildUnitList()),
            ]),
    );
  }

  Widget _buildPackHeader() {
    if (_packs.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
        child: Row(children: [
          const Icon(Icons.info_outline, color: _purpleL, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('No Grade Pack installed. Tap Import to load Grade 9 Offline Study Pack.',
              style: TextStyle(color: _text1, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _purple),
            onPressed: () => _importPack(),
            child: const Text('Import Pack', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ]),
      );
    }

    final p = _packs.first;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), _card2]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _purple.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: _purple.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('📚', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['pack_name'] ?? 'Grade 9 Offline Pack', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Grade ${p['grade']} • Version ${p['version']} • Size: ${p['size_formatted'] ?? '42 KB'}', style: const TextStyle(color: _text2, fontSize: 11)),
          const SizedBox(height: 2),
          Text('✅ 100% Phone Offline Study Mode (No Internet Needed)', style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  Widget _buildSubjectSelector() {
    return Container(
      color: _card,
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _subjects.length,
        itemBuilder: (ctx, i) {
          final s = _subjects[i];
          final active = _selectedSubject == s;
          final label = s.replaceAll('_', ' ').toUpperCase();
          return GestureDetector(
            onTap: () {
              setState(() => _selectedSubject = s);
              _loadSubjectUnits();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? _purple : _card2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: active ? _purpleL : _border),
              ),
              child: Center(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.white : _text2))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnitList() {
    if (_loadingUnit) {
      return const Center(child: CircularProgressIndicator(color: _purpleL));
    }
    if (_units.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.folder_open_rounded, size: 48, color: _text2),
          const SizedBox(height: 12),
          Text('No study units ready for ${_selectedSubject.replaceAll('_', ' ').toUpperCase()}', style: const TextStyle(color: _text2, fontSize: 14)),
          const SizedBox(height: 6),
          const Text('Tap Import to refresh pack content.', style: TextStyle(color: _text2, fontSize: 11)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _units.length,
      itemBuilder: (ctx, i) {
        final u = _units[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _card2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openUnitStudy(u['unit_number']),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text('UNIT ${u['unit_number']}', style: const TextStyle(color: _purpleL, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(u['unit_title'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _text2),
                ]),
                if (u['overview'] != null && u['overview'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(u['overview'].toString(), style: const TextStyle(color: _text2, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (u['has_concepts'] == true) _badge('💡 Concepts', _purpleL),
                  if (u['has_glossary'] == true) _badge('📚 Glossary', Colors.blueAccent),
                  if (u['has_exercises'] == true) _badge('📝 Exercises', Colors.amber),
                  if (u['has_quiz'] == true) _badge('🎯 Practice Quiz', _green),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  // ── Unit Study Detail Dialog
  void _showUnitDetailModal(Map<String, dynamic> unitData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _dark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UnitStudySheet(unitData: unitData),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unit Study Sheet with Tabs (Summary, Concepts, Glossary, Exercises, Quiz)
// ─────────────────────────────────────────────────────────────────────────────
class _UnitStudySheet extends StatefulWidget {
  final Map<String, dynamic> unitData;
  const _UnitStudySheet({required this.unitData});

  @override
  State<_UnitStudySheet> createState() => _UnitStudySheetState();
}

class _UnitStudySheetState extends State<_UnitStudySheet> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.unitData['summary']?['unit_title'] ?? "Unit ${widget.unitData['unit_number']}";
    final subject = (widget.unitData['subject'] ?? '').toString().toUpperCase();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(children: [
        // Handle bar & Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(color: _card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 10),
            Row(children: [
              Text('$subject • UNIT ${widget.unitData['unit_number']}', style: const TextStyle(color: _purpleL, fontSize: 11, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: _text2, size: 20), onPressed: () => Navigator.pop(context)),
            ]),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        ),

        // Tabs Bar
        Container(
          color: _card2,
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            indicatorColor: _purpleL,
            labelColor: Colors.white,
            unselectedLabelColor: _text2,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: '📖 Summary'),
              Tab(text: '💡 Concepts'),
              Tab(text: '📚 Glossary'),
              Tab(text: '📝 Exercises'),
              Tab(text: '🎯 Practice Quiz'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildSummaryTab(),
              _buildConceptsTab(),
              _buildGlossaryTab(),
              _buildExercisesTab(),
              _buildQuizTab(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildSummaryTab() {
    final s = widget.unitData['summary'];
    if (s == null) return const Center(child: Text('No summary available.', style: TextStyle(color: _text2)));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📖 Unit Overview', style: TextStyle(color: _purpleL, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(s['unit_overview'] ?? s['overview'] ?? '', style: const TextStyle(color: _text1, fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.menu_book, size: 14, color: _text2),
              const SizedBox(width: 6),
              Text('Source: ${s['source_book'] ?? ''} (Pages ${s['source_pages'] ?? ''})', style: const TextStyle(color: _text2, fontSize: 11)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildConceptsTab() {
    final list = (widget.unitData['concepts']?['concepts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (list.isEmpty) return const Center(child: Text('No concepts found in this unit.', style: TextStyle(color: _text2)));
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final c = list[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c['name'] ?? 'Concept', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
              if (c['source_pages'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('Pg ${c['source_pages']}', style: const TextStyle(color: _purpleL, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 6),
            Text(c['simple_definition'] ?? '', style: const TextStyle(color: _text1, fontSize: 13, height: 1.4)),
            if (c['deep_explanation'] != null) ...[
              const SizedBox(height: 8),
              Text(c['deep_explanation'], style: const TextStyle(color: _text2, fontSize: 12, height: 1.4)),
            ],
            if (c['real_example'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💡 ', style: TextStyle(fontSize: 12)),
                  Expanded(child: Text('Example: ${c['real_example']}', style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11))),
                ]),
              ),
            ],
            if (c['common_confusion'] != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF2A1215), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('⚠️ ', style: TextStyle(fontSize: 12)),
                  Expanded(child: Text('Common Trap: ${c['common_confusion']}', style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11))),
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }

  Widget _buildGlossaryTab() {
    final list = (widget.unitData['glossary']?['terms'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (list.isEmpty) return const Center(child: Text('Glossary terms in progress.', style: TextStyle(color: _text2)));
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final g = list[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g['term'] ?? '', style: const TextStyle(color: _purpleL, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(g['definition'] ?? '', style: const TextStyle(color: _text1, fontSize: 12)),
          ]),
        );
      },
    );
  }

  Widget _buildExercisesTab() {
    final list = (widget.unitData['exercises']?['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (list.isEmpty) return const Center(child: Text('No exercises found in this unit.', style: TextStyle(color: _text2)));
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _ExerciseCard(ex: list[i], index: i + 1),
    );
  }

  Widget _buildQuizTab() {
    final list = (widget.unitData['practice_quiz']?['practice_quiz'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (list.isEmpty) return const Center(child: Text('No practice quiz for this unit.', style: TextStyle(color: _text2)));
    return _QuizPlayer(questions: list);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exercise Card with Solution Toggle
// ─────────────────────────────────────────────────────────────────────────────
class _ExerciseCard extends StatefulWidget {
  final Map<String, dynamic> ex;
  final int index;
  const _ExerciseCard({required this.ex, required this.index});

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _showSolution = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: Text('EXERCISE ${widget.index}', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          if (widget.ex['source_page'] != null)
            Text('Page ${widget.ex['source_page']}', style: const TextStyle(color: _text2, fontSize: 10)),
        ]),
        const SizedBox(height: 8),
        Text(widget.ex['question'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _showSolution = !_showSolution),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: _purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: _purple.withValues(alpha: 0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_showSolution ? Icons.visibility_off : Icons.visibility, size: 14, color: _purpleL),
              const SizedBox(width: 6),
              Text(_showSolution ? 'Hide Verified Solution' : 'Show Verified Solution', style: const TextStyle(color: _purpleL, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        if (_showSolution) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF06152B), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E3A8A))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('✅ Answer: ${widget.ex['correct_answer'] ?? ''}', style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.bold)),
              if (widget.ex['step_by_step_explanation'] != null) ...[
                const SizedBox(height: 6),
                Text('Working & Explanation:\n${widget.ex['step_by_step_explanation']}', style: const TextStyle(color: _text1, fontSize: 11, height: 1.4)),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Quiz Player
// ─────────────────────────────────────────────────────────────────────────────
class _QuizPlayer extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  const _QuizPlayer({required this.questions});

  @override
  State<_QuizPlayer> createState() => _QuizPlayerState();
}

class _QuizPlayerState extends State<_QuizPlayer> {
  final Map<int, String> _selectedAnswers = {};
  int _score = 0;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: widget.questions.length + 1,
      itemBuilder: (ctx, i) {
        if (i == widget.questions.length) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(14), border: Border.all(color: _purpleL)),
            child: Column(children: [
              const Text('🎯 Practice Quiz Progress', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Answered: ${_selectedAnswers.length} of ${widget.questions.length}', style: const TextStyle(color: _text2, fontSize: 12)),
            ]),
          );
        }

        final q = widget.questions[i];
        final type = q['type'] ?? 'multiple_choice';
        final userAns = _selectedAnswers[i];
        final correctAns = (q['correct_answer'] ?? '').toString().trim();
        final answered = userAns != null;

        List<String> options = [];
        if (type == 'true_false') {
          options = ['True', 'False'];
        } else if (q['options'] is List) {
          options = (q['options'] as List).map((e) => e.toString()).toList();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Text('Q${i + 1}', style: const TextStyle(color: _purpleL, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(q['question'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 12),
            Column(
              children: options.map((opt) {
                final isSelected = userAns == opt;
                final isCorrect = opt.trim().toLowerCase() == correctAns.toLowerCase();
                Color borderColor = _border;
                Color bgColor = _dark;

                if (answered) {
                  if (isSelected && isCorrect) {
                    borderColor = _green; bgColor = _green.withValues(alpha: 0.15);
                  } else if (isSelected && !isCorrect) {
                    borderColor = _red; bgColor = _red.withValues(alpha: 0.15);
                  } else if (isCorrect) {
                    borderColor = _green;
                  }
                }

                return GestureDetector(
                  onTap: () {
                    if (!answered) {
                      setState(() {
                        _selectedAnswers[i] = opt;
                        if (isCorrect) _score++;
                      });
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                    child: Row(children: [
                      Expanded(child: Text(opt, style: TextStyle(color: isSelected ? Colors.white : _text1, fontSize: 12))),
                      if (answered && isCorrect) const Icon(Icons.check_circle_rounded, color: _green, size: 16),
                      if (answered && isSelected && !isCorrect) const Icon(Icons.cancel_rounded, color: _red, size: 16),
                    ]),
                  ),
                );
              }).toList(),
            ),
            if (answered && q['explanation'] != null) ...[
              const SizedBox(height: 8),
              Text('💡 ${q['explanation']}', style: const TextStyle(color: _text2, fontSize: 11, height: 1.3)),
            ],
          ]),
        );
      },
    );
  }
}
