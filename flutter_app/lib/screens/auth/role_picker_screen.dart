import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/home_screen.dart';

class RolePickerScreen extends StatelessWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95), Color(0xFF7C3AED)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🎓', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 6),
                      Text('EduLink', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Who are you?',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1.1),
                ),
                const SizedBox(height: 10),
                Text(
                  'Choose your role to get started with EduLink.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
                ),
                const SizedBox(height: 48),
                _RoleCard(
                  emoji: '🎒',
                  title: 'I\'m a Student',
                  subtitle: 'Join classes, complete assignments,\ntake quizzes & track progress',
                  color: const Color(0xFF7C3AED),
                  features: const ['Join classes with a code', 'Submit assignments', 'Take quizzes', 'Chat with classmates'],
                  onTap: () => _selectRole(context, 'student'),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  emoji: '👨‍🏫',
                  title: 'I\'m a Teacher',
                  subtitle: 'Create classes, upload lessons,\nassign work & track student progress',
                  color: const Color(0xFF0891B2),
                  features: const ['Create & manage classes', 'Upload lessons', 'Create assignments & quizzes', 'Grade & give feedback'],
                  onTap: () => _selectRole(context, 'teacher'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectRole(BuildContext context, String role) async {
    final result = await context.read<AuthProvider>().updateRole(role);
    if (!context.mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color color;
  final List<String> features;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: features.map((f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(f, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w500)),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
