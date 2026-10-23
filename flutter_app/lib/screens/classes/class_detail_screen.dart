import 'package:flutter/material.dart';
import '../../models/school_class.dart';
import '../lessons/lessons_tab.dart';
import '../assignments/assignments_tab.dart';
import '../quizzes/quizzes_tab.dart';
import 'class_qr_dialog.dart';
import 'announcements_tab.dart';
import 'students_tab.dart';

class ClassDetailScreen extends StatelessWidget {
  final SchoolClass schoolClass;
  const ClassDetailScreen({super.key, required this.schoolClass});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(schoolClass.name),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Lessons'),
            Tab(text: 'Assignments'),
            Tab(text: 'Quizzes'),
            Tab(text: 'Announcements'),
            Tab(text: 'Students'),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'Show join QR code',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ClassQrDialog(className: schoolClass.name, joinCode: schoolClass.joinCode),
              ),
            ),
          ],
        ),
        body: TabBarView(children: [
          LessonsTab(classId: schoolClass.id),
          AssignmentsTab(classId: schoolClass.id),
          QuizzesTab(classId: schoolClass.id),
          AnnouncementsTab(classId: schoolClass.id),
          StudentsTab(classId: schoolClass.id),
        ]),
      ),
    );
  }
}
