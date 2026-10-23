import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EduLink AI Screen — Textbook-aware + General AI
//  • Select your grade(s) → AI only answers from those textbooks
//  • Teaches step-by-step, never gives direct answers
//  • Shows page images from the textbook
//  • General questions still use Gemini/Groq/Mistral (cloud AI)
// ─────────────────────────────────────────────────────────────────────────────

// Brand colors
const _purple  = Color(0xFF7C3AED);
const _purpleL = Color(0xFFA855F7);
const _dark    = Color(0xFF060612);
const _card    = Color(0xFF0F0F24);
const _card2   = Color(0xFF111127);
const _text1   = Color(0xFFE5E7EB);
const _text2   = Color(0xFF9CA3AF);
const _border  = Color(0xFF1F1F3A);

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> with TickerProviderStateMixin {
  final _api    = ApiClient();
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];

  bool _loading = false;
  String _language = 'en';
  bool _textbookMode = true; // true = textbook AI, false = general AI

  // Selected grades (multi-select)
  final Set<int> _selectedGrades = {9};

  // Selected subjects filter
  String _selectedSubject = 'All';

  late AnimationController _gradeAnimCtrl;
  bool _gradeExpanded = true;

  static const _allSubjects = [
    'All', 'Mathematics', 'Biology', 'Chemistry', 'Physics',
    'English', 'History', 'Geography', 'Economics',
    'Citizenship', 'Social Studies', 'Information Technology',
  ];

  static const _quickActions = [
    _QA(emoji: '📖', label: 'Explain Page', prompt: 'Please explain page '),
    _QA(emoji: '🔢', label: 'Help with Exercise', prompt: 'Help me understand Unit  Exercise '),
    _QA(emoji: '📋', label: 'List Topics', prompt: 'What topics are covered in '),
    _QA(emoji: '🗺️', label: 'Summarize Chapter', prompt: 'Summarize chapter/unit '),
    _QA(emoji: '❓', label: "I Don't Understand", prompt: "I don't understand: "),
    _QA(emoji: '🌐', label: 'Ask in Amharic', prompt: 'በአማርኛ አስረዳኝ: '),
  ];

  @override
  void initState() {
    super.initState();
    _gradeAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _gradeAnimCtrl.forward();
    // Welcome message
    _msgs.add(_Msg(
      isAi: true,
      text: '👋 **Welcome to EduLink AI!**\n\n'
          'I am your personal textbook tutor. I have read all your Ethiopian curriculum textbooks '
          '(Grades 1–12) deeply.\n\n'
          '**Select your grade(s) above**, then ask me anything:\n'
          '• *"Help me with Unit 2 Exercise 2.3 Mathematics"*\n'
          '• *"What is on page 47?"*\n'
          '• *"Explain photosynthesis"*\n'
          '• *"I don\'t understand quadratic equations"*\n\n'
          'I will **teach** you — not just give answers! 📚',
      provider: 'EduLink AI',
      pages: [],
    ));
  }

  @override
  void dispose() {
    _gradeAnimCtrl.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Grade button groups ─────────────────────────────────────────────────
  void _setGradeBundle(List<int> grades) {
    setState(() {
      _selectedGrades.clear();
      _selectedGrades.addAll(grades);
    });
  }

  // ── Send message ────────────────────────────────────────────────────────
  Future<void> _send([String? prefill]) async {
    final text = (prefill ?? _ctrl.text).trim();
    if (text.isEmpty || _loading) return;

    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg(isAi: false, text: text));
      _loading = true;
    });
    _scrollDown();

    try {
      Map<String, dynamic> result;

      if (_textbookMode && _selectedGrades.isNotEmpty) {
        // ── Textbook AI call with conversation history
        final history = _msgs.length > 1
            ? _msgs.takeLast(10).map((m) => {
                'role': m.isAi ? 'assistant' : 'user',
                'content': m.text,
              }).toList()
            : [];
        final res = await _api.safeCall(() => _api.dio.post('/ai/textbook/query', data: {
          'question': text,
          'grades':   _selectedGrades.toList(),
          'subjects': _selectedSubject == 'All' ? [] : [_selectedSubject],
          'language': _language,
          'history':  history,
        }));
        if (res.success && res.data != null) {
          result = res.data!;
        } else {
          // Fallback to general AI
          result = await _generalAiCall(text);
        }
      } else {
        // ── General AI call
        result = await _generalAiCall(text);
      }

      final responseText = result['response'] as String? ??
          result['data']?['response'] as String? ??
          'Sorry, I could not generate a response.';
      final provider = result['provider'] as String? ??
          result['data']?['provider'] as String? ?? 'AI';
      final pages = (result['pages'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      setState(() {
        _msgs.add(_Msg(isAi: true, text: responseText, provider: provider, pages: pages));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _msgs.add(_Msg(isAi: true, text: 'An error occurred. Please check your connection.', provider: 'Error'));
        _loading = false;
      });
    }
    _scrollDown();
  }

  Future<Map<String, dynamic>> _generalAiCall(String text) async {
    final context = _msgs.length > 1
        ? _msgs.takeLast(6).map((m) => {'role': m.isAi ? 'assistant' : 'user', 'content': m.text}).toList()
        : [];
    final res = await _api.safeCall(() => _api.dio.post('/ai/ask', data: {
      'prompt':   text,
      'language': _language,
      'provider': 'auto',
      'context':  context,
    }));
    return res.data ?? {'response': 'Could not reach AI service.'};
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, dynamic>? _selectedPageForSplitView;
  bool _showSplitBookPanel = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget chatContent = Column(children: [
      // ── Grade selector panel
      _buildGradePanel(),
      // ── Mode toggle + subject filter
      _buildModeAndSubjectBar(),
      // ── Chat messages
      Expanded(child: _buildMessageList()),
      // ── Quick actions
      if (_msgs.length <= 1) _buildQuickActions(),
      // ── Input bar
      _buildInputBar(),
    ]);

    if (!isDesktop || !_showSplitBookPanel || _selectedPageForSplitView == null) {
      return Scaffold(
        backgroundColor: _dark,
        appBar: _buildAppBar(),
        body: chatContent,
      );
    }

    // Split View Desktop Layout: Left = AI Chat, Right = Textbook Page Viewer
    return Scaffold(
      backgroundColor: _dark,
      appBar: _buildAppBar(),
      body: Row(children: [
        Expanded(flex: 55, child: chatContent),
        Container(width: 1, color: _border),
        Expanded(flex: 45, child: _buildDesktopBookPanel()),
      ]),
    );
  }

  Widget _buildDesktopBookPanel() {
    final page = _selectedPageForSplitView!;
    final imageUrl = page['image_url'] as String?;

    return Container(
      color: _card,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: _card2,
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(children: [
            const Text('📖 ', style: TextStyle(fontSize: 18)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Grade ${page['grade']} ${page['subject']} — Page ${page['printed_page_number'] ?? page['page_number']}',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                if (page['chapter'] != null)
                  Text(page['chapter'] as String, style: const TextStyle(color: _text2, fontSize: 11)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: _text2, size: 20),
              tooltip: 'Close Textbook Panel',
              onPressed: () => setState(() => _showSplitBookPanel = false),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    minScale: 0.8, maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(color: _purpleL)),
                      errorBuilder: (_, __, ___) => Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                        child: const Center(child: Text('📄 Page Image Viewer\n(Indexed Textbook Image Preview)', style: TextStyle(color: _text2), textAlign: TextAlign.center)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (page['preview'] != null) ...[
                const Text('📝 Textbook Page Extract:', style: TextStyle(color: _purpleL, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                  child: Text(page['preview'] as String, style: const TextStyle(color: _text1, fontSize: 12, height: 1.5)),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────
  AppBar _buildAppBar() => AppBar(
    backgroundColor: _card,
    elevation: 0,
    title: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_purple, _purpleL]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.4), blurRadius: 8)],
        ),
        child: const Center(child: Text('🧠', style: TextStyle(fontSize: 18))),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('EduLink AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _text1)),
        Text(_textbookMode ? 'Textbook Mode — Your Books' : 'General AI Mode',
          style: const TextStyle(fontSize: 10, color: _text2)),
      ]),
    ]),
    actions: [
      // Language selector
      PopupMenuButton<String>(
        onSelected: (v) => setState(() => _language = v),
        icon: Row(children: [
          Text(_langEmoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 16, color: _text2),
        ]),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'en', child: Text('🇺🇸 English')),
          PopupMenuItem(value: 'am', child: Text('🇪🇹 አማርኛ (Amharic)')),
          PopupMenuItem(value: 'om', child: Text('🇪🇹 Afaan Oromo')),
          PopupMenuItem(value: 'ti', child: Text('🇪🇹 Tigrinya')),
        ],
      ),
      const SizedBox(width: 8),
    ],
  );

  String get _langEmoji {
    switch (_language) {
      case 'am': case 'om': case 'ti': return '🇪🇹';
      default: return '🇺🇸';
    }
  }

  // ── Grade Panel ─────────────────────────────────────────────────────────
  Widget _buildGradePanel() {
    return Container(
      decoration: const BoxDecoration(
        color: _card2,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        GestureDetector(
          onTap: () {
            setState(() => _gradeExpanded = !_gradeExpanded);
            if (_gradeExpanded) {
              _gradeAnimCtrl.forward();
            } else {
              _gradeAnimCtrl.reverse();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Text('📚', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('My Grades: ${_selectedGrades.isEmpty ? "None selected" : _selectedGrades.map((g) => "G$g").join(", ")}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text1)),
              const Spacer(),
              AnimatedRotation(
                turns: _gradeExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: _text2, size: 20),
              ),
            ]),
          ),
        ),

        // Expandable content
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _gradeExpanded ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Quick bundles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _BundleChip(label: 'Primary (1-6)',  onTap: () => _setGradeBundle([1,2,3,4,5,6])),
                  _BundleChip(label: 'Ministry (7-8)', onTap: () => _setGradeBundle([7,8])),
                  _BundleChip(label: 'Jr.High (7-10)', onTap: () => _setGradeBundle([7,8,9,10])),
                  _BundleChip(label: 'High (9-12)',    onTap: () => _setGradeBundle([9,10,11,12])),
                  _BundleChip(label: 'All Grades',     onTap: () => _setGradeBundle(List.generate(12, (i) => i+1))),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            // Individual grade buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: List.generate(12, (i) {
                  final grade = i + 1;
                  final selected = _selectedGrades.contains(grade);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedGrades.remove(grade);
                      } else {
                        _selectedGrades.add(grade);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44, height: 36,
                      decoration: BoxDecoration(
                        color: selected ? _purple : _card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? _purple : _border, width: 1.5),
                        boxShadow: selected ? [BoxShadow(
                          color: _purple.withValues(alpha: 0.4), blurRadius: 8)] : null,
                      ),
                      child: Center(child: Text('G$grade',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : _text2))),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
          ]) : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  // ── Mode + Subject Bar ──────────────────────────────────────────────────
  Widget _buildModeAndSubjectBar() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        // Textbook / General toggle
        GestureDetector(
          onTap: () => setState(() => _textbookMode = !_textbookMode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _textbookMode ? _purple.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _textbookMode ? _purple : _border, width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_textbookMode ? '📚' : '🤖', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(_textbookMode ? 'Textbook' : 'General',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: _textbookMode ? _purpleL : _text2)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        // Subject filter
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _allSubjects.map((s) {
                final active = _selectedSubject == s;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSubject = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? _purple : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: active ? _purple : _border),
                    ),
                    child: Text(s, style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: active ? Colors.white : _text2)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Message List ────────────────────────────────────────────────────────
  Widget _buildMessageList() => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    itemCount: _msgs.length + (_loading ? 1 : 0),
    itemBuilder: (ctx, i) {
      if (i == _msgs.length) return const _TypingIndicator();
      final isLastAi = _msgs[i].isAi && i == _msgs.length - 1;
      return _MessageBubble(
        msg: _msgs[i],
        onPageTap: _showPageImage,
        onActionTap: isLastAi && !_loading ? (prompt) => _send(prompt) : null,
      );
    },
  );

  void _showPageImage(Map<String, dynamic> page) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    if (isDesktop) {
      setState(() {
        _selectedPageForSplitView = page;
        _showSplitBookPanel = true;
      });
      return;
    }

    final imageUrl = page['image_url'] as String?;
    if (imageUrl == null) return;

    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF060612),
        child: Scaffold(
          backgroundColor: const Color(0xFF060612),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F0F24),
            elevation: 0,
            title: Text('📄 Grade ${page['grade']} ${page['subject']} — Page ${page['page_number']}',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                          color: _purple,
                        ),
                      ),
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Page image not available.\nMake sure textbooks are indexed.',
                    style: TextStyle(color: _text2),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Quick Actions ───────────────────────────────────────────────────────
  Widget _buildQuickActions() => Container(
    color: _card,
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Actions', style: TextStyle(fontSize: 11, color: _text2, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _quickActions.map((qa) => GestureDetector(
          onTap: () { _ctrl.text = qa.prompt; _ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _ctrl.text.length)); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Text('${qa.emoji} ${qa.label}',
              style: const TextStyle(fontSize: 12, color: _text2)),
          ),
        )).toList(),
      ),
    ]),
  );

  // ── Input Bar ───────────────────────────────────────────────────────────
  Widget _buildInputBar() => Container(
    color: _card,
    padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).viewInsets.bottom),
    child: SafeArea(
      top: false,
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF373760)),
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              cursorColor: const Color(0xFFA855F7),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E1E38),
                hintText: _textbookMode
                    ? 'Ask about your textbooks...'
                    : 'Ask anything...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _loading ? null : _send,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: _loading
                  ? const LinearGradient(colors: [Color(0xFF374151), Color(0xFF374151)])
                  : const LinearGradient(colors: [_purple, _purpleL]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _loading ? null : [BoxShadow(
                color: _purple.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: _loading
                ? const Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Message Bubble
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _Msg msg;
  final void Function(Map<String, dynamic>) onPageTap;
  final void Function(String)? onActionTap;

  const _MessageBubble({
    required this.msg,
    required this.onPageTap,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!msg.isAi) {
      // User message
      return Padding(
        padding: const EdgeInsets.only(bottom: 14, left: 40),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purple, _purpleL]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4)),
              boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: SelectableText(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
            ),
          ),
        ),
      );
    }

    // AI message
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Provider badge + Copy Button
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _purpleL]),
                borderRadius: BorderRadius.circular(6)),
              child: const Center(child: Text('🧠', style: TextStyle(fontSize: 12)))),
            const SizedBox(width: 6),
            Text(msg.provider ?? 'EduLink AI', style: const TextStyle(fontSize: 10, color: _text2, fontWeight: FontWeight.w600)),
            const Spacer(),
            _CopyButton(text: msg.text),
          ]),
        ),
        // Message content
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _card2,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4), topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            border: Border.all(color: _border),
          ),
          child: SelectionArea(
            child: MarkdownBody(
              data: msg.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p:            const TextStyle(color: _text1, fontSize: 14, height: 1.6),
                strong:       const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                em:           const TextStyle(color: Color(0xFFF472B6), fontStyle: FontStyle.italic),
                h1:           const TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w800),
                h2:           const TextStyle(color: _purpleL, fontSize: 16, fontWeight: FontWeight.w700),
                h3:           const TextStyle(color: Color(0xFF60A5FA), fontSize: 15, fontWeight: FontWeight.w700),
                h4:           const TextStyle(color: Color(0xFFFBBF24), fontSize: 14, fontWeight: FontWeight.w700),
                code:         const TextStyle(color: Color(0xFF38BDF8), backgroundColor: Color(0xFF0C2A38), fontSize: 13, fontWeight: FontWeight.bold),
                blockquote:   const TextStyle(color: Color(0xFFFDE68A), fontSize: 13, height: 1.5, fontWeight: FontWeight.w600),
                blockquoteDecoration: BoxDecoration(
                  color: const Color(0xFF26200B),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: Color(0xFFF59E0B), width: 4)),
                ),
                blockquotePadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ),
        // Page references
        if (msg.pages.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: msg.pages.map((page) => _PageRefChip(
              page: page, onTap: () => onPageTap(page))).toList()),
          ),
        ],
        // Suggested action buttons
        if (onActionTap != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              _ActionBtn(icon: Icons.search_rounded, label: 'Explain more', onTap: () => onActionTap!('Explain more.')),
              _ActionBtn(icon: Icons.lightbulb_outline_rounded, label: 'Give example', onTap: () => onActionTap!('Give me an example.')),
              _ActionBtn(icon: Icons.quiz_outlined, label: 'Quiz me', onTap: () => onActionTap!('Quiz me.')),
              _ActionBtn(icon: Icons.menu_book_rounded, label: 'Show textbook page', onTap: () => onActionTap!('Show the page.')),
            ],
          ),
        ],
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _purpleL),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _text1)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Page Reference Chip
// ─────────────────────────────────────────────────────────────────────────────
class _PageRefChip extends StatelessWidget {
  final Map<String, dynamic> page;
  final VoidCallback onTap;

  const _PageRefChip({required this.page, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF111127),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _purple.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('📄', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${page['subject']} — Pg ${page['printed_page_number'] ?? page['page_number']}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _purpleL)),
          if (page['chapter'] != null)
            Text(page['chapter'] as String,
              style: const TextStyle(fontSize: 9, color: _text2)),
        ]),
        if (page['has_image'] == true) ...[
          const SizedBox(width: 6),
          const Icon(Icons.image_outlined, size: 12, color: _text2),
        ],
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Supporting widgets and data classes
// ─────────────────────────────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_purple, _purpleL]),
          borderRadius: BorderRadius.circular(6)),
        child: const Center(child: Text('🧠', style: TextStyle(fontSize: 12)))),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _card2, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border)),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.3 + _anim.value * 0.7 * (i == 1 ? 1 : 0.6)),
                  shape: BoxShape.circle),
              ),
            ],
          ]),
        ),
      ),
    ]),
  );
}

class _BundleChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _BundleChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _purple.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: _purpleL, fontWeight: FontWeight.w600)),
    ),
  );
}

class _Msg {
  final bool isAi;
  final String text;
  final String? provider;
  final List<Map<String, dynamic>> pages;

  _Msg({required this.isAi, required this.text, this.provider, this.pages = const []});
}

class _QA {
  final String emoji, label, prompt;
  const _QA({required this.emoji, required this.label, required this.prompt});
}

extension on Iterable<_Msg> {
  Iterable<_Msg> takeLast(int n) {
    final list = toList();
    return list.length <= n ? list : list.sublist(list.length - n);
  }
}

class _CopyButton extends StatefulWidget {
  final String text;
  const _CopyButton({required this.text});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
      if (!mounted) return;
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Solution copied to clipboard!'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (e) {
      debugPrint('Clipboard copy error: $e');
      if (mounted) {
        setState(() => _copied = true);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 Text highlighted! Press Ctrl+C to copy.'),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF7C3AED),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _copied ? const Color(0xFF064E3B) : const Color(0xFF1E1E38),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _copied ? const Color(0xFF10B981) : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 13,
              color: _copied ? const Color(0xFF34D399) : _text2,
            ),
            const SizedBox(width: 4),
            Text(
              _copied ? 'Copied!' : 'Copy',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _copied ? const Color(0xFF34D399) : _text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
