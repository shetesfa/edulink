import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../models/school_class.dart';
import 'class_detail_screen.dart';
import 'join_class_dialog.dart';
import 'create_class_dialog.dart';
import 'scan_class_qr_screen.dart';

class ClassesListScreen extends StatefulWidget {
  const ClassesListScreen({super.key});

  @override
  State<ClassesListScreen> createState() => _ClassesListScreenState();
}

class _ClassesListScreenState extends State<ClassesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().currentUser?.id;
      context.read<ClassProvider>().loadClasses(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTeacher = ['teacher', 'school_admin', 'super_admin'].contains(auth.currentUser?.roleName);
    final classProvider = context.watch<ClassProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Classes')),
      body: RefreshIndicator(
        onRefresh: () => context.read<ClassProvider>().loadClasses(auth.currentUser?.id),
        child: classProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (isTeacher) ...[
                    Text('Teaching', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...classProvider.teaching.map((c) => _ClassCard(schoolClass: c)),
                    const SizedBox(height: 24),
                  ],
                  Text('Enrolled', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (classProvider.enrolled.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No classes yet. Join one with a code!')),
                    ),
                  ...classProvider.enrolled.map((c) => _ClassCard(schoolClass: c)),
                ],
              ),
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Create class'),
              onPressed: () => showDialog(context: context, builder: (_) => const CreateClassDialog()),
            )
          : FloatingActionButton.extended(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Join class'),
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => SafeArea(
                  child: Wrap(children: [
                    ListTile(
                      leading: const Icon(Icons.qr_code_scanner),
                      title: const Text('Scan QR code'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanClassQrScreen()));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.keyboard),
                      title: const Text('Enter code manually'),
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(context: context, builder: (_) => const JoinClassDialog());
                      },
                    ),
                  ]),
                ),
              ),
            ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final SchoolClass schoolClass;
  const _ClassCard({required this.schoolClass});

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _parseColor(schoolClass.color), child: const Icon(Icons.class_, color: Colors.white)),
        title: Text(schoolClass.name),
        subtitle: Text(schoolClass.subject ?? schoolClass.teacherName ?? ''),
        trailing: Text('${schoolClass.studentsCount} students'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ClassDetailScreen(schoolClass: schoolClass)),
        ),
      ),
    );
  }
}
