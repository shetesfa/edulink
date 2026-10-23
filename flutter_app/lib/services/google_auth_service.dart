import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../screens/dashboard/home_screen.dart';
import '../screens/auth/google_signin_webview.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleAuthService {
  static const _serverClientId =
      '264019535722-fg4ic8fo6b15uj6na9s5ijtcrgais7t4.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _serverClientId,
  );

  static Future<bool> signInWithGoogle(BuildContext context) async {
    Map<String, dynamic>? authData;

    if (kIsWeb) {
      final googleUrl = Uri.parse('${ApiConfig.baseDomain}/api/auth/google');
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl, webOnlyWindowName: '_self');
      }
      return true;
    }


    try {
      // 1. Try Native Google Sign-In directly
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled account selection
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final api = ApiClient();
      final result = await api.safeCall(() => api.dio.post('/auth/google/mobile', data: {
        'id_token': googleAuth.idToken,
        'access_token': googleAuth.accessToken,
      }));

      if (result.success && result.data != null) {
        authData = result.data;
      }
    } on PlatformException catch (_) {
      // Fall back to Web-based Google OAuth flow if native Google Sign-In (SHA-1 / Play Services) fails
      if (context.mounted) {
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (_) => const GoogleSignInWebView()),
        );
        if (result != null) {
          authData = result;
        } else {
          return false;
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Google sign-in failed. Check your connection and try again.'),
        ));
      }
      return false;
    }

    if (authData != null && context.mounted) {
      // Complete login and navigate directly to dashboard
      await context.read<AuthProvider>().loginWithGoogleResponse(authData);
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return true;
      }
    }

    return false;
  }
}
