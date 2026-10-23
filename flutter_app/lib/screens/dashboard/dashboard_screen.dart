import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../ai/ai_screen.dart';
import '../classes/classes_list_screen.dart';
import '../classes/create_class_dialog.dart';
import '../labs/labs_list_screen.dart';


// Brand colors matching the web app
class EduColors {
  static const brand600 = Color(0xFF7C3AED);
  static const brand100 = Color(0xFFEDE9FE);
  static const bg = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const border = Color(0xFFF3F4F6);

  static const colorViolet = Color(0xFF7C3AED);
  static const colorBlue = Color(0xFF2563EB);
  static const colorGreen = Color(0xFF059669);
  static const colorAmber = Color(0xFFD97706);
  static const colorRed = Color(0xFFDC2626);
  static const colorCyan = Color(0xFF0891B2);

  static LinearGradient get brandGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFFC084FC)],
  );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    final result = await _api.safeCall(() => _api.dio.get('/dashboard'));
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _data = result.data!['data'] ?? result.data;
        } else {
          _error = result.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final role = user?.roleName ?? 'student';

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final horizontalPadding = isDesktop ? 32.0 : 16.0;

    return Scaffold(
      // Respect the selected light/dark theme instead of forcing a pale
      // background when dark mode is enabled.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const _DashboardSkeleton()
          : RefreshIndicator(
              color: EduColors.brand600,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(user),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, isDesktop ? 28 : 16, horizontalPadding, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (_error != null) _buildError(),
                        if (role == 'student') ..._buildStudentDashboard(isDesktop),
                        if (role == 'teacher') ..._buildTeacherDashboard(),
                        if (role == 'admin' || role == 'school_admin' || role == 'super_admin') ..._buildAdminDashboard(),
                        const SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSliverAppBar(user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final emoji = hour < 12 ? '☀️' : hour < 17 ? '👋' : '🌙';

    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: EduColors.brand600,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: EduColors.brandGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🎓', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 4),
                            Text('EduLink', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Language quick toggle
                      Consumer<SettingsProvider>(
                        builder: (ctx, sp, _) => GestureDetector(
                          onTap: () {
                            sp.changeLanguage(sp.language == 'en' ? 'am' : 'en');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.language, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  sp.language == 'en' ? 'EN' : 'አማ',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 18),
                        ),
                      ),
                    ],

                  ),
                  const SizedBox(height: 14),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white),
                      children: [
                        TextSpan(text: '$greeting, ${user?.firstName ?? ''} $emoji'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(_error ?? 'Failed to load dashboard', style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  List<Widget> _buildStudentDashboard(bool isDesktop) {
    final stats = _data?['stats'] as Map<String, dynamic>? ?? {};
    final upcoming = ((_data?['upcoming_assignments'] ?? []) as List).map((x) => x as Map<String, dynamic>).toList();
    final recentLessons = ((_data?['recent_lessons'] ?? []) as List).map((x) => x as Map<String, dynamic>).toList();
    final notifications = ((_data?['notifications'] ?? []) as List).map((x) => x as Map<String, dynamic>).toList();

    return [
      // Stat Cards
      _buildStatCards([
        _StatCard(label: 'Classes Joined', value: '${stats['classes'] ?? 0}', icon: Icons.school_outlined, color: EduColors.colorViolet, bg: EduColors.brand100),
        _StatCard(label: 'Lessons Viewed', value: '${stats['lessons'] ?? 0}', icon: Icons.play_circle_outline, color: EduColors.colorBlue, bg: const Color(0xFFDBEAFE)),
        _StatCard(label: 'Assignments Done', value: '${stats['assignments'] ?? 0}', icon: Icons.check_circle_outline, color: EduColors.colorGreen, bg: const Color(0xFFD1FAE5)),
        _StatCard(label: 'Quiz Average', value: '${stats['avg_quiz'] ?? 0}%', icon: Icons.emoji_events_outlined, color: EduColors.colorAmber, bg: const Color(0xFFFEF3C7)),
      ]),
      const SizedBox(height: 20),
      // AI Quick Access
      _buildAIBanner(),
      const SizedBox(height: 12),
      // 3D Interactive Science Labs Banner
      _build3DLabsBanner(),
      const SizedBox(height: 20),
      // Due Soon + Continue Learning in a row
      if (isDesktop)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildDueSoon(upcoming)),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: _buildWeeklyActivity()),
          ],
        )
      else ...[
        _buildDueSoon(upcoming),
        const SizedBox(height: 12),
        _buildWeeklyActivity(),
      ],
      const SizedBox(height: 20),
      // Continue Learning
      _buildContinueLearning(recentLessons),
      const SizedBox(height: 20),
      // Recent notifications
      if (notifications.isNotEmpty) _buildNotifications(notifications),
    ];
  }

  List<Widget> _buildTeacherDashboard() {
    final stats = _data?['stats'] as Map<String, dynamic>? ?? {};
    final classes = ((_data?['classes'] ?? []) as List).map((x) => x as Map<String, dynamic>).toList();
    final pending = ((_data?['pending_submissions'] ?? []) as List).map((x) => x as Map<String, dynamic>).toList();

    return [
      // Teacher stat cards
      _buildStatCards([
        _StatCard(label: 'My Classes', value: '${stats['total_classes'] ?? 0}', icon: Icons.class_outlined, color: EduColors.colorViolet, bg: EduColors.brand100),
        _StatCard(label: 'Total Students', value: '${stats['total_students'] ?? 0}', icon: Icons.people_outline, color: EduColors.colorCyan, bg: const Color(0xFFCFFAFE)),
        _StatCard(label: 'Pending Grades', value: '${stats['pending_grades'] ?? 0}', icon: Icons.access_time_outlined, color: EduColors.colorAmber, bg: const Color(0xFFFEF3C7)),
        _StatCard(label: 'Avg Quiz Score', value: '${stats['avg_quiz'] ?? 0}%', icon: Icons.emoji_events_outlined, color: EduColors.colorGreen, bg: const Color(0xFFD1FAE5)),
      ]),
      const SizedBox(height: 20),
      // Quick actions row
      _buildTeacherQuickActions(),
      const SizedBox(height: 20),
      // Needs grading
      _buildNeedsGrading(pending),
      const SizedBox(height: 20),
      // My classes
      _buildMyClasses(classes),
    ];
  }

  List<Widget> _buildAdminDashboard() {
    final stats = _data ?? {};
    return [
      _buildStatCards([
        _StatCard(label: 'Total Users', value: '${stats['total_users'] ?? 0}', icon: Icons.people_outline, color: EduColors.colorViolet, bg: EduColors.brand100),
        _StatCard(label: 'Classes', value: '${stats['total_classes'] ?? 0}', icon: Icons.class_outlined, color: EduColors.colorBlue, bg: const Color(0xFFDBEAFE)),
        _StatCard(label: 'New (7d)', value: '${stats['new_users_last_7_days'] ?? 0}', icon: Icons.person_add_outlined, color: EduColors.colorGreen, bg: const Color(0xFFD1FAE5)),
        _StatCard(label: 'Schools', value: '${stats['total_schools'] ?? 0}', icon: Icons.account_balance_outlined, color: EduColors.colorAmber, bg: const Color(0xFFFEF3C7)),
      ]),
    ];
  }

  Widget _buildStatCards(List<_StatCard> cards) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1180 ? 4 : 2;
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: columns == 4 ? 1.75 : 1.5,
      children: cards.map((s) => _buildStatCardWidget(s)).toList(),
    );
  }

  Widget _buildStatCardWidget(_StatCard s) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassesListScreen())),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(s.icon, color: s.color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: EduColors.textPrimary)),
                Text(s.label, style: const TextStyle(fontSize: 12, color: EduColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIBanner() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      shadowColor: EduColors.brand600.withValues(alpha: 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiScreen())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: EduColors.brandGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('🤖', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Study Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Explain concepts, generate quizzes,\ntranslate to Amharic & more', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: const Text('Ask AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DLabsBanner() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LabsListScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('🔬', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('3D Interactive Science Labs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Chemistry 3D, Biology Anatomy, 3D Geometry & Physics', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20)),
                child: const Text('Open 3D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDueSoon(List<Map<String, dynamic>> upcoming) {
    return _SectionCard(
      title: 'Due Soon',
      trailing: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassesListScreen())),
        child: const Text('View all', style: TextStyle(color: EduColors.brand600, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      child: upcoming.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('No upcoming assignments 🎉', style: TextStyle(color: EduColors.textMuted, fontSize: 12))),
            )
          : Column(
              children: upcoming.take(4).map((a) => _AssignmentRow(assignment: a)).toList(),
            ),
    );
  }

  Widget _buildWeeklyActivity() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final activity = (_data?['activity'] as List? ?? []);
    return _SectionCard(
      title: 'This Week',
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final val = i < activity.length ? (activity[i]['lessons'] as num?)?.toDouble() ?? 0.0 : (i * 1.1 % 4);
              const maxVal = 5.0;
              final height = (val / maxVal * 60).clamp(4.0, 60.0);
              final isToday = i == DateTime.now().weekday - 1;
              return Column(
                children: [
                  Container(
                    width: 16,
                    height: height,
                    decoration: BoxDecoration(
                      color: isToday ? EduColors.brand600 : EduColors.brand600.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(days[i], style: TextStyle(fontSize: 9, color: isToday ? EduColors.brand600 : EduColors.textMuted, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildContinueLearning(List<Map<String, dynamic>> lessons) {
    return _SectionCard(
      title: 'Continue Learning',
      trailing: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassesListScreen())),
        child: const Text('All classes', style: TextStyle(color: EduColors.brand600, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      child: lessons.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.menu_book_outlined, color: EduColors.textMuted, size: 32),
                  const SizedBox(height: 8),
                  const Text('Join a class to start learning', style: TextStyle(color: EduColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassesListScreen())),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Browse classes'),
                    style: TextButton.styleFrom(foregroundColor: EduColors.brand600),
                  ),
                ],
              ),
            )
          : Column(
              children: lessons.take(3).map((l) => InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassesListScreen())),
                child: _LessonRow(lesson: l),
              )).toList(),
            ),
    );
  }

  Widget _buildNotifications(List<Map<String, dynamic>> notifications) {
    return _SectionCard(
      title: 'Recent Notifications',
      child: Column(
        children: notifications.take(4).map((n) => ListTile(
          dense: true,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: EduColors.brand100, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.notifications_outlined, color: EduColors.brand600, size: 16),
          ),
          title: Text(n['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(n['body'] ?? '', style: const TextStyle(fontSize: 11, color: EduColors.textMuted)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        )).toList(),
      ),
    );
  }

  Widget _buildTeacherQuickActions() {
    final actions = [
      _QuickAction(
        label: 'Upload\nLesson',
        icon: Icons.upload_outlined,
        color: EduColors.colorViolet,
        bg: EduColors.brand100,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassesListScreen())),
      ),
      _QuickAction(
        label: 'Create\nAssignment',
        icon: Icons.assignment_outlined,
        color: EduColors.colorBlue,
        bg: const Color(0xFFDBEAFE),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassesListScreen())),
      ),
      _QuickAction(
        label: 'Create\nQuiz',
        icon: Icons.quiz_outlined,
        color: EduColors.colorGreen,
        bg: const Color(0xFFD1FAE5),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassesListScreen())),
      ),
      _QuickAction(
        label: 'New\nClass',
        icon: Icons.add_circle_outline,
        color: EduColors.colorAmber,
        bg: const Color(0xFFFEF3C7),
        onTap: () => showDialog(context: context, builder: (_) => const CreateClassDialog()),
      ),
    ];
    return Row(
      children: actions.map((a) => Expanded(
        child: GestureDetector(
          onTap: a.onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: a.bg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(a.icon, color: a.color, size: 18),
                ),
                const SizedBox(height: 6),
                Text(a.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: EduColors.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildNeedsGrading(List<Map<String, dynamic>> pending) {
    return _SectionCard(
      title: 'Needs Grading',
      trailing: pending.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(20)),
              child: Text('${pending.length}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
            )
          : null,
      child: pending.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 28),
                  SizedBox(height: 6),
                  Text('All caught up! 🎉', style: TextStyle(color: EduColors.textMuted, fontSize: 13)),
                ],
              ),
            )
          : Column(
              children: pending.take(5).map((s) => ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.description_outlined, color: Color(0xFFF97316), size: 16),
                ),
                title: Text(s['student_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(s['assignment_title'] ?? '', style: const TextStyle(fontSize: 11, color: EduColors.textMuted)),
                trailing: const Icon(Icons.chevron_right, size: 16, color: EduColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              )).toList(),
            ),
    );
  }

  Widget _buildMyClasses(List<Map<String, dynamic>> classes) {
    return _SectionCard(
      title: 'My Classes',
      trailing: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassesListScreen())),
        child: const Text('Manage all →', style: TextStyle(color: EduColors.brand600, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      child: classes.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.class_outlined, color: EduColors.textMuted, size: 32),
                  const SizedBox(height: 8),
                  const Text('No classes yet. Create your first!', style: TextStyle(color: EduColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => showDialog(context: context, builder: (_) => const CreateClassDialog()),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Create Class'),
                    style: FilledButton.styleFrom(backgroundColor: EduColors.brand600, textStyle: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          : Column(
              children: classes.take(4).map((cls) {
                final colors = [EduColors.colorViolet, EduColors.colorBlue, EduColors.colorCyan, EduColors.colorGreen];
                final idx = (cls['id'] as int? ?? 0) % colors.length;
                return InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassesListScreen())),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: EduColors.border),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors[idx],
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cls['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: EduColors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(cls['grade']?['name'] ?? cls['subject'] ?? '', style: const TextStyle(fontSize: 11, color: EduColors.textMuted)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.people_outline, size: 12, color: EduColors.textMuted),
                                        const SizedBox(width: 3),
                                        Text('${cls['enrollments_count'] ?? cls['students_count'] ?? 0}', style: const TextStyle(fontSize: 11, color: EduColors.textMuted)),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.menu_book_outlined, size: 12, color: EduColors.textMuted),
                                        const SizedBox(width: 3),
                                        Text('${cls['lessons_count'] ?? 0} lessons', style: const TextStyle(fontSize: 11, color: EduColors.textMuted)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (cls['join_code'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: EduColors.border, borderRadius: BorderRadius.circular(8)),
                                  child: Text(cls['join_code'] ?? '', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: EduColors.textSecondary)),
                                ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right, size: 16, color: EduColors.textMuted),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  String _formatDate() {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

class _StatCard {
  final String label, value;
  final IconData icon;
  final Color color, bg;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.bg});
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color, bg;
  final VoidCallback? onTap;
  const _QuickAction({required this.label, required this.icon, required this.color, required this.bg, this.onTap});
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: EduColors.textPrimary)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final Map<String, dynamic> assignment;
  const _AssignmentRow({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final due = assignment['due_date'] != null ? DateTime.tryParse(assignment['due_date']) : null;
    final now = DateTime.now();
    Color dueColor = EduColors.textMuted;
    if (due != null) {
      final diff = due.difference(now).inHours;
      if (diff < 24) {
        dueColor = EduColors.colorRed;
      } else if (diff < 72) {
        dueColor = const Color(0xFFF97316);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.description_outlined, color: Color(0xFFF97316), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assignment['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EduColors.textPrimary), overflow: TextOverflow.ellipsis),
                Text(assignment['class_name'] ?? '', style: const TextStyle(fontSize: 11, color: EduColors.textMuted)),
              ],
            ),
          ),
          if (due != null)
            Text(
              'Due ${_shortDate(due)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dueColor),
            ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _LessonRow extends StatelessWidget {
  final Map<String, dynamic> lesson;
  const _LessonRow({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final progress = (lesson['progress'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: EduColors.brand100, borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('📖', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EduColors.textPrimary), overflow: TextOverflow.ellipsis),
                Text(lesson['class_name'] ?? '', style: const TextStyle(fontSize: 11, color: EduColors.textMuted)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: EduColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(EduColors.brand600),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${progress.toInt()}%', style: const TextStyle(fontSize: 10, color: EduColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EduColors.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(height: 140, decoration: BoxDecoration(gradient: EduColors.brandGradient, borderRadius: BorderRadius.circular(0))),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: List.generate(4, (_) => _shimmerBox(height: 80)),
            ),
            const SizedBox(height: 16),
            _shimmerBox(height: 80),
            const SizedBox(height: 16),
            _shimmerBox(height: 200),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox({double height = 60}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
