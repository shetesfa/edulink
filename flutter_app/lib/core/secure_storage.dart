import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'edulink_auth_token';
  static String? _memoryToken;

  static Future<void> saveToken(String token) async {
    _memoryToken = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (_) {}
  }

  static Future<String?> getToken() async {
    if (_memoryToken != null && _memoryToken!.isNotEmpty) {
      return _memoryToken;
    }
    try {
      final t = await _storage.read(key: _tokenKey);
      if (t != null && t.isNotEmpty) {
        _memoryToken = t;
        return t;
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(_tokenKey);
      if (t != null && t.isNotEmpty) {
        _memoryToken = t;
        return t;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearToken() async {
    _memoryToken = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }
}
