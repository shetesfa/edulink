import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../providers/auth_provider.dart';
import 'create_lesson_screen.dart';

class LessonsTab extends StatefulWidget {
  final int classId;
  const LessonsTab({super.key, required this.classId});

  @override
  State<LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<LessonsTab> {
  final _api = ApiClient();
  List<dynamic> _rawLessons = [];
  bool _isLoading = true;
  final Set<String> _collapsedChapters = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/classes/${widget.classId}/lessons'));
    if (result.success && result.data != null) {
      final list = result.data!['data']['lessons'] as List? ?? [];
      setState(() => _rawLessons = list);
    }
    setState(() => _isLoading = false);
  }

  /// Groups lessons by chapter_name. null/empty → "Uncategorized"
  Map<String, List<Map<String, dynamic>>> _grouped() {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final raw in _rawLessons) {
      final lesson = raw as Map<String, dynamic>;
      final chapter = (lesson['chapter_name'] as String?)?.trim();
      final key = (chapter != null && chapter.isNotEmpty) ? chapter : '__none__';
      map.putIfAbsent(key, () => []).add(lesson);
    }
    // Sort newest first within each chapter
    for (final key in map.keys) {
      map[key]!.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
    }
    return map;
  }

  bool _isNew(Map<String, dynamic> lesson) {
    final created = DateTime.tryParse(lesson['created_at'] ?? '');
    if (created == null) return false;
    return DateTime.now().difference(created).inDays < 3;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isTeacher = user?.roleName == 'teacher' || user?.roleName == 'admin' ||
        user?.roleName == 'school_admin' || user?.roleName == 'super_admin';

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final grouped = _grouped();

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
                    .push(MaterialPageRoute(builder: (_) => CreateLessonScreen(classId: widget.classId)))
                    .then((_) => _load()),
                icon: const Icon(Icons.add),
                label: const Text('Add Lesson / Book'),
              ),
            ),
          Expanded(
            child: grouped.isEmpty
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(children: [
                        Icon(Icons.menu_book_outlined, size: 52, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No lessons yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                      ]),
                    )
                  ])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: grouped.entries.map((entry) {
                      final chapterKey = entry.key;
                      final chapterName = chapterKey == '__none__' ? null : chapterKey;
                      final lessons = entry.value;
                      final isCollapsed = _collapsedChapters.contains(chapterKey);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (chapterName != null) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() {
                                if (isCollapsed) {
                                  _collapsedChapters.remove(chapterKey);
                                } else {
                                  _collapsedChapters.add(chapterKey);
                                }
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.folder_open, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        chapterName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text('${lessons.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(isCollapsed ? Icons.expand_more : Icons.expand_less, color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ] else
                            const SizedBox(height: 8),
                          if (!isCollapsed)
                            ...lessons.asMap().entries.map((le) {
                              final lesson = le.value;
                              final isNew = _isNew(lesson);
                              final isFirst = le.key == 0;

                              return Card(
                                margin: const EdgeInsets.only(top: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isFirst && chapterName != null
                                      ? const BorderSide(color: Color(0xFF7C3AED), width: 1.5)
                                      : BorderSide.none,
                                ),
                                elevation: isFirst ? 2 : 1,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => LessonDetailScreen(lessonId: lesson['id']),
                                  )),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF7C3AED).withValues(alpha: isFirst ? 0.15 : 0.07),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.menu_book, color: const Color(0xFF7C3AED), size: isFirst ? 20 : 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                if (isNew) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF059669),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    lesson['title'] ?? '',
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isFirst ? const Color(0xFF1F1235) : const Color(0xFF374151)),
                                                  ),
                                                ),
                                              ]),
                                              if (lesson['description'] != null && lesson['description'].toString().isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(lesson['description'], style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              ],
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                const Icon(Icons.attach_file, size: 11, color: Colors.grey),
                                                const SizedBox(width: 2),
                                                Text('${(lesson['files'] as List?)?.length ?? 0} files', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                const SizedBox(width: 10),
                                                const Icon(Icons.visibility_outlined, size: 11, color: Colors.grey),
                                                const SizedBox(width: 2),
                                                Text('${lesson['views'] ?? 0} views', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                              ]),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Lesson Detail — content + file downloads
// ─────────────────────────────────────────────
class LessonDetailScreen extends StatefulWidget {
  final int lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _lesson;
  bool _isBookmarked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _api.safeCall(() => _api.dio.get('/lessons/${widget.lessonId}'));
    if (result.success && result.data != null) {
      setState(() {
        _lesson = result.data!['data']['lesson'];
        _isBookmarked = result.data!['data']['is_bookmarked'] ?? false;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBookmark() async {
    final result = await _api.safeCall(() => _api.dio.post('/lessons/${widget.lessonId}/bookmark'));
    if (result.success) {
      setState(() => _isBookmarked = result.data!['data']['bookmarked']);
    }
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final rawUrl = file['url'] ?? file['file_url'] ?? file['path'];
    final url = ApiConfig.resolveMediaUrl(rawUrl?.toString());
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open this file.')));
      }
    }
  }

  IconData _iconForFile(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': case 'docx': return Icons.description;
      case 'ppt': case 'pptx': return Icons.slideshow;
      case 'xls': case 'xlsx': return Icons.table_chart;
      case 'jpg': case 'jpeg': case 'png': return Icons.image;
      default: return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = (_lesson?['files'] as List? ?? []);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text(_lesson?['title'] ?? 'Lesson', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: Colors.white),
            tooltip: _isBookmarked ? 'Remove bookmark' : 'Bookmark',
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lesson == null
              ? const Center(child: Text('Could not load lesson.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chapter badge
                      if (_lesson!['chapter_name'] != null && _lesson!['chapter_name'].toString().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.folder_outlined, size: 12, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 4),
                            Text(_lesson!['chapter_name'], style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Title
                      Text(_lesson!['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1F1235))),
                      const SizedBox(height: 10),
                      // Description
                      if (_lesson!['description'] != null && _lesson!['description'].toString().isNotEmpty) ...[
                        Card(
                          color: const Color(0xFFF3E8FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.info_outline, color: Color(0xFF7C3AED), size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_lesson!['description'], style: const TextStyle(fontSize: 13, color: Color(0xFF4B1FA8), height: 1.5))),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      // Stats row
                      Row(children: [
                        const Icon(Icons.visibility_outlined, size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text('${_lesson!['views'] ?? 0} views', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 14),
                        const Icon(Icons.attach_file, size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text('${files.length} file${files.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                      const SizedBox(height: 16),

                      // File attachments — books
                      if (files.isNotEmpty) ...[
                        const Row(children: [
                          Icon(Icons.library_books, color: Color(0xFF7C3AED), size: 18),
                          SizedBox(width: 8),
                          Text('Books & Files', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ]),
                        const SizedBox(height: 8),
                        ...files.map((f) {
                          final file = f as Map<String, dynamic>;
                          final name = file['original_name'] ?? file['name'] ?? 'File';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Icon(_iconForFile(name), color: const Color(0xFF7C3AED), size: 24),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                                      if (file['download_count'] != null)
                                        Text('${file['download_count']} downloads', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ]),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.open_in_new, color: Color(0xFF7C3AED), size: 20),
                                        tooltip: 'Open',
                                        onPressed: () => _openFile(file),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.download, color: Color(0xFF059669), size: 20),
                                        tooltip: 'Download',
                                        onPressed: () => _openFile(file),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const Divider(height: 24),
                      ],

                      // Lesson content / notes
                      if (_lesson!['content'] != null && _lesson!['content'].toString().isNotEmpty) ...[
                        const Row(children: [
                          Icon(Icons.notes, color: Color(0xFF7C3AED), size: 18),
                          SizedBox(width: 8),
                          Text('Lesson Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ]),
                        const SizedBox(height: 10),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_lesson!['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF374151))),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}
