import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class CreateLessonScreen extends StatefulWidget {
  final int classId;
  const CreateLessonScreen({super.key, required this.classId});

  @override
  State<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends State<CreateLessonScreen> {
  final _api = ApiClient();
  final _chapterController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _contentController = TextEditingController();
  final List<PlatformFile> _attachedFiles = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _chapterController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        // Add without duplicates by name
        final existingNames = _attachedFiles.map((f) => f.name).toSet();
        for (final f in result.files) {
          if (!existingNames.contains(f.name)) {
            _attachedFiles.add(f);
          }
        }
      });
    }
  }

  void _removeFile(int index) => setState(() => _attachedFiles.removeAt(index));

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

  Future<void> _createLesson() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson title is required.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description is required.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final formMap = <String, dynamic>{
      'title': _titleController.text.trim(),
      'chapter_name': _chapterController.text.trim().isEmpty ? null : _chapterController.text.trim(),
      'description': _descController.text.trim(),
      'content': _contentController.text.trim(),
      'is_published': 1,
    };

    if (_attachedFiles.isNotEmpty) {
      final multiFiles = <MultipartFile>[];
      for (final f in _attachedFiles) {
        if (f.path != null) {
          multiFiles.add(await MultipartFile.fromFile(f.path!, filename: f.name));
        }
      }
      formMap['attachments[]'] = multiFiles;
    }

    final result = await _api.safeCall(() => _api.dio.post(
          '/classes/${widget.classId}/lessons',
          data: FormData.fromMap(formMap),
        ));

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Lesson published successfully.'),
          backgroundColor: Color(0xFF059669),
        ));
        nav.pop(true);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(result.message), backgroundColor: Colors.red.shade700));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isTeacher = user?.roleName == 'teacher' || user?.roleName == 'admin' ||
        user?.roleName == 'school_admin' || user?.roleName == 'super_admin';

    if (!isTeacher) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Lesson')),
        body: const Center(child: Text('Only teachers can add lessons.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('Add New Lesson', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.25)),
              onPressed: _isLoading ? null : _createLesson,
              child: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter name
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.folder_outlined, color: Color(0xFF7C3AED), size: 18),
                      SizedBox(width: 6),
                      Text('Chapter (optional)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED), fontSize: 13)),
                    ]),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _chapterController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Chapter 1: Introduction to Forces',
                        helperText: 'Leave empty if not part of a chapter. Same name = same chapter group.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Lesson details
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.menu_book, color: Color(0xFF7C3AED), size: 18),
                      SizedBox(width: 6),
                      Text('Lesson Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED), fontSize: 13)),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Lesson Title *',
                        hintText: 'e.g. Newton\'s Second Law of Motion',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description *',
                        hintText: 'Brief summary — what students will learn',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contentController,
                      maxLines: 10,
                      decoration: InputDecoration(
                        labelText: 'Lesson Notes / Content',
                        hintText: 'Type the full lesson explanation, formulas, examples...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // File attachments
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_file, color: Color(0xFF7C3AED), size: 18),
                        const SizedBox(width: 6),
                        const Expanded(child: Text('Book / File Attachments', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED), fontSize: 13))),
                        TextButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Files'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
                        ),
                      ],
                    ),
                    const Text('PDF, PPTX, Word, images — students can open & download.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    if (_attachedFiles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ..._attachedFiles.asMap().entries.map((e) {
                        final f = e.value;
                        final sizeMB = (f.size / (1024 * 1024)).toStringAsFixed(1);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          color: const Color(0xFFF3E8FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            dense: true,
                            leading: Icon(_iconForFile(f.name), color: const Color(0xFF7C3AED), size: 22),
                            title: Text(f.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                            subtitle: Text('$sizeMB MB', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              onPressed: () => _removeFile(e.key),
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _pickFiles,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), style: BorderStyle.solid),
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.cloud_upload_outlined, color: Color(0xFF7C3AED), size: 32),
                                SizedBox(height: 6),
                                Text('Tap to attach PDF, PPTX, Word, or any file', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
