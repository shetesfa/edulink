import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../core/api_client.dart';
import '../dashboard/home_screen.dart';
import 'google_signin_webview.dart';

/// Native Google Sign-In using the official google_sign_in package
/// This provides the proper Chrome account chooser experience
class GoogleSignInNative extends StatefulWidget {
  const GoogleSignInNative({super.key});

  @override
  State<GoogleSignInNative> createState() => _GoogleSignInNativeState();
}

class _GoogleSignInNativeState extends State<GoogleSignInNative> {
  static const _serverClientId =
      '264019535722-fg4ic8fo6b15uj6na9s5ijtcrgais7t4.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _serverClientId,
  );
  
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Sign out first to ensure account chooser appears
      await _googleSignIn.signOut();

      // Trigger the native Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).pop();
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Send the Google tokens to your backend for verification
      final api = ApiClient();
      final result = await api.safeCall(() => api.dio.post('/auth/google/mobile', data: {
        'id_token': googleAuth.idToken,
        'access_token': googleAuth.accessToken,
      }));

      if (!mounted) return;

      if (result.success && result.data != null) {
        // Backend returns token and user data
        await context.read<AuthProvider>().loginWithGoogleResponse(result.data!);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = result.message;
          _isLoading = false;
        });
      }
    } on PlatformException catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GoogleSignInWebView()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Google Sign-In failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.account_circle,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sign in with Google',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose your Google account to continue',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              FilledButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.account_circle),
                label: Text(_isLoading ? 'Signing in...' : 'Continue with Google'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
