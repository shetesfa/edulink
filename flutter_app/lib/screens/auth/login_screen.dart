import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/google_logo_icon.dart';
import '../../l10n/app_localizations.dart';
import 'register_screen.dart';
import 'otp_login_screen.dart';
import 'forgot_password_screen.dart';
import 'verify_email_screen.dart';
import '../../services/google_auth_service.dart';
import '../dashboard/home_screen.dart';
import '../../core/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your backend API URL. For testing on physical Android phone, use your PC local Wi-Fi IP:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'http://10.90.191.180:8000/api',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiConfig.clearCustomUrl();
              if (!mounted) return;
              Navigator.pop(ctx);
              setState(() => _errorMessage = null);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reset URL to default: ${ApiConfig.baseUrl}')),
              );
            },
            child: const Text('Reset to Default'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                await ApiConfig.setCustomUrl(controller.text.trim());
                if (!mounted) return;
                nav.pop();
                setState(() => _errorMessage = null);
                messenger.showSnackBar(
                  SnackBar(content: Text('Server URL set to: ${ApiConfig.baseUrl}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final result = await auth.login(_emailController.text.trim(), _passwordController.text);

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      setState(() => _isLoading = false);
      if (result.data?['data']?['requires_verification'] == true) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: _emailController.text.trim()),
        ));
        return;
      }
      setState(() => _errorMessage = result.message);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await GoogleAuthService.signInWithGoogle(context);

    if (mounted && !success) {
      setState(() => _isLoading = false);
    }
  }

  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Language toggle
          TextButton.icon(
            onPressed: () {
              final newLang = settings.language == 'en' ? 'am' : 'en';
              context.read<SettingsProvider>().changeLanguage(newLang);
            },
            icon: const Icon(Icons.language_rounded, size: 18),
            label: Text(
              settings.language == 'en' ? 'EN' : 'አማ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet_rounded),
            tooltip: 'Server Settings',
            onPressed: _showServerSettingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.school_rounded, size: 56, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'EduLink',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Ethiopian School Learning & Communication',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome Back',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text('Sign in to continue to your dashboard', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: t.email,
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: t.password,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                              ),
                              child: Text(t.forgotPassword),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: _showServerSettingsDialog,
                                      icon: const Icon(Icons.settings_ethernet, size: 16),
                                      label: const Text('Change Server IP', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          FilledButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(t.login),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('OR', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.mark_email_read_outlined, size: 20),
                            label: Text(t.loginWithCode),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const OtpLoginScreen()),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFDADCE0), width: 1.5),
                              backgroundColor: Colors.white,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GoogleLogoIcon(size: 22),
                                SizedBox(width: 12),
                                Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    color: Color(0xFF3C4043),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.dontHaveAccount, style: theme.textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: Text(t.signUp, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
