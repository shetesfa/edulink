import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/user.dart';
import '../auth/login_screen.dart';
import '../portfolio/portfolio_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isUploadingPhoto = false;

  Future<void> _changePhoto(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    // FilePicker supports Windows, macOS, Linux, web, and mobile. ImagePicker
    // does not provide a gallery implementation on desktop platforms.
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    final photoPath = picked?.files.single.path;
    if (photoPath == null || photoPath.isEmpty) return;

    if (!mounted) return;
    setState(() => _isUploadingPhoto = true);

    // Profile photos are handled by the same authenticated profile endpoint
    // as the rest of a user's details.  Keeping the request in AuthProvider
    // also ensures the locally displayed user is updated after a successful
    // upload.
    final result = await auth.updateProfileDetails(
      firstName: auth.currentUser?.firstName ?? '',
      lastName: auth.currentUser?.lastName ?? '',
      username: auth.currentUser?.username,
      filePath: photoPath,
    );

    if (!mounted) return;
    setState(() => _isUploadingPhoto = false);

    if (result.success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully!')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'Failed to update photo.')),
      );
    }
  }

  void _showEditProfileDialog(BuildContext context, AppUser? user) {
    final firstNameController = TextEditingController(text: user?.firstName ?? '');
    final lastNameController = TextEditingController(text: user?.lastName ?? '');
    final usernameController = TextEditingController(text: user?.username ?? '');
    String? selectedPhotoPath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username (for search)',
                    hintText: 'e.g. @tesfa123',
                    prefixText: '@',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera),
                  label: Text(selectedPhotoPath != null ? 'Photo Selected' : 'Choose Profile Photo'),
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(type: FileType.image);
                    if (res != null && res.files.single.path != null) {
                      setState(() => selectedPhotoPath = res.files.single.path);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (firstNameController.text.trim().isNotEmpty) {
                  final auth = context.read<AuthProvider>();
                  final result = await auth.updateProfileDetails(
                    firstName: firstNameController.text.trim(),
                    lastName: lastNameController.text.trim(),
                    username: usernameController.text.trim(),
                    filePath: selectedPhotoPath,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.success ? 'Profile updated successfully!' : result.message)),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _langName(String code) {
    const names = {
      'en': '🇬🇧 English',
      'am': '🇪🇹 አማርኛ (Amharic)',
      'om': '🇪🇹 Afaan Oromoo',
      'ti': '🇪🇹 ትግርኛ (Tigrinya)',
      'so': '🇸🇴 Soomaali',
      'ar': '🇸🇦 العربية',
      'fr': '🇫🇷 Français',
    };
    return names[code] ?? 'English';
  }

  void _showLanguagePicker(BuildContext context, SettingsProvider settings) {
    const langs = [
      ('en', '🇬🇧 English'),
      ('am', '🇪🇹 አማርኛ (Amharic)'),
      ('om', '🇪🇹 Afaan Oromoo'),
      ('ti', '🇪🇹 ትግርኛ (Tigrinya)'),
      ('so', '🇸🇴 Soomaali'),
      ('ar', '🇸🇦 العربية'),
      ('fr', '🇫🇷 Français'),
    ];
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Select Language / ቋንቋ ምረጥ'),
        children: langs.map((lang) {
          final isSelected = settings.language == lang.$1;
          return SimpleDialogOption(
            onPressed: () {
              context.read<SettingsProvider>().changeLanguage(lang.$1);
              Navigator.pop(context);
            },
            child: Row(
              children: [
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 18, color: isSelected ? const Color(0xFF7C3AED) : Colors.grey),
                const SizedBox(width: 12),
                Text(lang.$2, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _isUploadingPhoto ? null : () => _changePhoto(context),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          child: user?.fullProfilePhotoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    user!.fullProfilePhotoUrl!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(
                                      user.firstName.isNotEmpty ? user.firstName.substring(0, 1).toUpperCase() : 'U',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                    loadingBuilder: (_, child, progress) =>
                                        progress == null ? child : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                )
                              : Text(
                                  user?.firstName.isNotEmpty == true ? user!.firstName.substring(0, 1).toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                        ),
                        if (_isUploadingPhoto)
                          const Positioned.fill(
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        else
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'User Profile',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                        if (user?.username != null && user!.username!.isNotEmpty)
                          Text(
                            '@${user.username}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF7C3AED),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Chip(
                          label: Text(
                            (user?.roleName ?? 'Student').toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Name',
                    onPressed: () => _showEditProfileDialog(context, user),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Portfolio shortcut
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 20),
              ),
              title: const Text('My Portfolio', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Achievements, badges & stats'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PortfolioScreen())),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('App Preferences', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),

          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: settings.darkMode,
            onChanged: (v) => context.read<SettingsProvider>().toggleDarkMode(v),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
