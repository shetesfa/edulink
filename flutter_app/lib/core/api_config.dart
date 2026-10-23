import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static String? _customUrl;

  /// Load environment variables from .env file and user-defined server override
  static Future<void> loadEnv() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Graceful fallback if .env fails to load
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_api_url');
      final envUrl = _getEnv('API_BASE_URL')?.trim();
      // If stored URL is from old session/IP or port 8010, purge it!
      if (savedUrl != null) {
        if (savedUrl.contains('8010') || savedUrl.contains('10.90.191.180') || (envUrl != null && envUrl.isNotEmpty && !savedUrl.contains(Uri.tryParse(envUrl)?.host ?? '___'))) {
          await prefs.remove('custom_api_url');
          _customUrl = null;
        } else {
          _customUrl = savedUrl;
        }
      }
    } catch (_) {}
  }

  /// Update the server URL at runtime and save to persistent storage
  static Future<void> setCustomUrl(String url) async {
    var cleaned = url.trim();
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    if (!cleaned.endsWith('/api')) {
      cleaned = cleaned.replaceFirst(RegExp(r'/$'), '');
      cleaned = '$cleaned/api';
    }
    _customUrl = cleaned;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_api_url', cleaned);
    } catch (_) {}
  }

  /// Clear any custom URL override (resets to .env or default)
  static Future<void> clearCustomUrl() async {
    _customUrl = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_api_url');
    } catch (_) {}
  }

  static String? _getEnv(String key) {
    if (dotenv.isInitialized) {
      return dotenv.env[key];
    }
    return null;
  }

  /// Base API URL — priority:
  /// 1. Valid user-set custom URL (if not containing 8010)
  /// 2. .env file API_BASE_URL (auto-updated by START_SERVER.bat)
  /// 3. Fallback: localhost for Web/Desktop, 10.0.2.2 for Android emulator
  static String get baseUrl {
    if (_customUrl != null && _customUrl!.isNotEmpty && !_customUrl!.contains('8010')) {
      return _customUrl!;
    }
    final envUrl = _getEnv('API_BASE_URL')?.trim();
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl.replaceFirst(RegExp(r'/$'), '');
    }
    // Android emulator fallback
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  /// Helper to get the base domain for redirects
  static String get baseDomain => baseUrl.replaceAll('/api', '');

  /// Reverb (realtime chat) connection details
  static String get reverbHost {
    final envHost = _getEnv('REVERB_HOST')?.trim();
    if (envHost != null && envHost.isNotEmpty) {
      return envHost;
    }
    // Extract host from baseUrl as fallback
    final uri = Uri.tryParse(baseDomain);
    return uri?.host ?? 'localhost';
  }

  static int get reverbPort {
    final port = _getEnv('REVERB_PORT');
    return port != null ? int.tryParse(port) ?? 8080 : 8080;
  }

  static String get reverbKey => _getEnv('REVERB_APP_KEY')?.trim() ?? 'edulink-local-2026-4cd7a08f';

  static bool get reverbUseTLS {
    final useTls = _getEnv('REVERB_USE_TLS');
    return useTls?.toLowerCase() == 'true';
  }

  /// Resolve media/file URLs dynamically so old IPs stored in DB are rewritten
  /// to match current server baseDomain seamlessly.
  static String? resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final cleaned = rawUrl.trim();
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      final uri = Uri.tryParse(cleaned);
      if (uri != null && uri.path.contains('/storage/')) {
        final storagePath = uri.path.substring(uri.path.indexOf('/storage/'));
        return '$baseDomain$storagePath';
      }
      return cleaned;
    }
    if (cleaned.startsWith('/storage/')) {
      return '$baseDomain$cleaned';
    }
    if (cleaned.startsWith('storage/')) {
      return '$baseDomain/$cleaned';
    }
    return '$baseDomain/storage/$cleaned';
  }
}

