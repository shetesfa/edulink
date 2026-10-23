import 'package:flutter/material.dart';
import 'admin_users_screen.dart';
import 'admin_classes_screen.dart';
import 'admin_audit_log_screen.dart';
import 'admin_stats_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard Statistics'),
              subtitle: const Text('Overview of platform usage'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminStatsScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people),
              title: const Text('User Management'),
              subtitle: const Text('Search, activate/deactivate, change roles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.class_),
              title: const Text('Class Moderation'),
              subtitle: const Text('View and deactivate classes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminClassesScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Audit Log'),
              subtitle: const Text('Every sensitive admin action, recorded'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminAuditLogScreen())),
            ),
          ),
        ],
      ),
    );
  }
}
