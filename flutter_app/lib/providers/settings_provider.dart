import 'package:flutter/material.dart';
import '../core/api_client.dart';

class SettingsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool darkMode = false;
  String language = 'en'; // en | am

  void loadFromUserSettings(Map<String, dynamic>? settings) {
    if (settings == null) return;
    darkMode = settings['dark_mode'] ?? false;
    language = settings['language'] ?? 'en';
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    darkMode = value;
    notifyListeners();
    await _api.safeCall(() => _api.dio.put('/settings', data: {'dark_mode': value}));
  }

  Future<void> changeLanguage(String value) async {
    language = value;
    notifyListeners();
    await _api.safeCall(() => _api.dio.put('/settings', data: {'language': value}));
  }
}
