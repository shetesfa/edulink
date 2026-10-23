import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const _badgeEmojis = {
    'Quiz Master': ('🏆', Color(0xFFFFD700)),
    'Perfect Streak': ('🔥', Color(0xFFFF6B35)),
    'Study Champion': ('🌟', Color(0xFF9B59B6)),
    'Active Learner': ('📚', Color(0xFF3498DB)),
    'Top Student': ('👑', Color(0xFFE74C3C)),
    'Fast Finisher': ('⚡', Color(0xFF2ECC71)),
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    final result = await _api.safeCall(() => _api.dio.get('/portfolio'));
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _data = result.data!['data'] ?? result.data;
          _animController.forward();
        } else {
          _error = result.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white30,
                        backgroundImage: user?.fullProfilePhotoUrl != null ? NetworkImage(user!.fullProfilePhotoUrl!) : null,
                        child: user?.fullProfilePhotoUrl == null
                            ? Text(
                                user?.firstName.isNotEmpty == true ? user!.firstName[0].toUpperCase() : 'S',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(user?.fullName ?? 'Student', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(user?.email ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                tooltip: 'Share Portfolio',
                onPressed: _sharePortfolio,
              ),
            ],
          ),

          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsGrid(theme),
                        const SizedBox(height: 20),
                        _buildBadgesSection(theme),
                        const SizedBox(height: 20),
                        _buildSubjectScores(theme),
                        const SizedBox(height: 20),
                        _buildRecentActivity(theme),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    final stats = _data?['stats'] as Map<String, dynamic>? ?? {};
    final items = [
      ('Lessons\nViewed', '${stats['lessons_viewed'] ?? 0}', Icons.play_circle_outline, const Color(0xFF7C3AED)),
      ('Quizzes\nTaken', '${stats['quizzes_taken'] ?? 0}', Icons.quiz_outlined, const Color(0xFF059669)),
      ('Assignments\nDone', '${stats['assignments_submitted'] ?? 0}', Icons.assignment_turned_in_outlined, const Color(0xFF2563EB)),
      ('Avg Score', '${stats['average_score'] ?? 0}%', Icons.stars_outlined, const Color(0xFFD97706)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Stats', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          // Use the available desktop width for a clean single-row summary,
          // while keeping the compact two-column layout on phones.
          crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: items.map((item) => _buildStatCard(item.$1, item.$2, item.$3, item.$4)).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(ThemeData theme) {
    final badges = (_data?['badges'] as List<dynamic>? ?? []).cast<String>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Achievements', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('${badges.length}', style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (badges.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text('Complete quizzes & assignments to earn badges!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges.map((badge) {
              final info = _badgeEmojis[badge] ?? ('🎖️', const Color(0xFF6B7280));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: info.$2.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: info.$2.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(info.$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(badge, style: TextStyle(fontWeight: FontWeight.w600, color: info.$2, fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSubjectScores(ThemeData theme) {
    final subjects = (_data?['subject_scores'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (subjects.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Score by Subject', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: subjects.map((s) {
              final score = (s['avg_score'] as num?)?.toDouble() ?? 0.0;
              final color = score >= 80 ? const Color(0xFF059669) : score >= 60 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${score.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(ThemeData theme) {
    final activity = (_data?['recent_activity'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (activity.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(
            children: activity.asMap().entries.map((entry) {
              final i = entry.key;
              final act = entry.value;
              final type = act['type'] as String? ?? '';
              final icon = type == 'quiz' ? Icons.quiz : type == 'assignment' ? Icons.assignment : Icons.book;
              final color = type == 'quiz' ? const Color(0xFF7C3AED) : type == 'assignment' ? const Color(0xFF2563EB) : const Color(0xFF059669);

              return Column(
                children: [
                  if (i > 0) Divider(height: 1, indent: 60, color: Colors.grey.shade100),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    title: Text(act['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    subtitle: Text(act['description'] ?? '', style: const TextStyle(fontSize: 12)),
                    trailing: Text(act['time'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _sharePortfolio() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final link = 'https://edulink.app/portfolio/${user.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Portfolio link copied!')]),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
