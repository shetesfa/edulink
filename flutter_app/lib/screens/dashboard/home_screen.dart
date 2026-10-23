import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import '../classes/classes_list_screen.dart';
import '../chat/conversations_screen.dart';
import '../ai/ai_screen.dart';
import '../settings/settings_screen.dart';
import '../admin/admin_home_screen.dart';
import '../study_rooms/study_rooms_screen.dart';
import '../grade_pack/grade_pack_screen.dart';
import '../../providers/auth_provider.dart';

import '../../widgets/offline_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final role = user?.roleName ?? 'student';
    final isAdmin = role == 'school_admin' || role == 'super_admin' || role == 'admin';

    final screens = [
      const DashboardScreen(),
      const ClassesListScreen(),
      const StudyRoomsScreen(),
      const GradePackScreen(),
      const AiScreen(),
      const ConversationsScreen(),
      if (isAdmin) const AdminHomeScreen(),
      const SettingsScreen(),
    ];

    if (_index >= screens.length) _index = 0;

    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 800;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    extended: true,
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    labelType: null,
                    minExtendedWidth: 238,
                    minWidth: 76,
                    backgroundColor: const Color(0xFF1E293B),
                    indicatorColor: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    unselectedIconTheme: const IconThemeData(color: Color(0xFF9CA3AF)),
                    selectedIconTheme: const IconThemeData(color: Color(0xFFA855F7)),
                    unselectedLabelTextStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), blurRadius: 10)],
                            ),
                            child: const Center(child: Text('🎓', style: TextStyle(fontSize: 24))),
                          ),
                          ...[
                            const SizedBox(width: 12),
                            const Text('EduLink', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
                          ],
                        ],
                      ),
                    ),
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard, color: Color(0xFF7C3AED)),
                        label: Text('Home'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.class_outlined),
                        selectedIcon: Icon(Icons.class_, color: Color(0xFF7C3AED)),
                        label: Text('Classes'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.groups_2_outlined),
                        selectedIcon: Icon(Icons.groups_2, color: Color(0xFF7C3AED)),
                        label: Text('Study'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2, color: Color(0xFF7C3AED)),
                        label: Text('Packs'),
                      ),
                      NavigationRailDestination(
                        icon: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
                        ),
                        label: const Text('AI'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.chat_bubble_outline),
                        selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF7C3AED)),
                        label: Text('Chat'),
                      ),
                      if (isAdmin)
                        const NavigationRailDestination(
                          icon: Icon(Icons.admin_panel_settings_outlined),
                          selectedIcon: Icon(Icons.admin_panel_settings, color: Color(0xFF7C3AED)),
                          label: Text('Admin'),
                        ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings, color: Color(0xFF7C3AED)),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE5E7EB)),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: IndexedStack(index: _index, children: screens),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(index: _index, children: screens),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(isAdmin),
    );
  }

  Widget _buildNavBar(bool isAdmin) {
    return NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFEDE9FE),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 70,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard, color: Color(0xFF7C3AED)),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.class_outlined),
          selectedIcon: Icon(Icons.class_, color: Color(0xFF7C3AED)),
          label: 'Classes',
        ),
        const NavigationDestination(
          icon: Icon(Icons.groups_2_outlined),
          selectedIcon: Icon(Icons.groups_2, color: Color(0xFF7C3AED)),
          label: 'Study',
        ),
        const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2, color: Color(0xFF7C3AED)),
          label: 'Packs',
        ),
        NavigationDestination(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
          ),
          selectedIcon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
          ),
          label: 'AI',
        ),
        const NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF7C3AED)),
          label: 'Chat',
        ),
        if (isAdmin)
          const NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings, color: Color(0xFF7C3AED)),
            label: 'Admin',
          ),
        const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings, color: Color(0xFF7C3AED)),
          label: 'Settings',
        ),
      ],
    );
  }
}
