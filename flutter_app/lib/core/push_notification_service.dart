import 'api_client.dart';

/// Push notification service stub. Real FCM push notifications require
/// adding google-services.json to android/app/.
class PushNotificationService {
  static final ApiClient _api = ApiClient();

  static Future<void> initialize() async {
    // Firebase push notifications disabled until google-services.json is configured
  }

  static Future<void> registerToken(String token) async {
    await _api.safeCall(() => _api.dio.post('/device-tokens', data: {'token': token, 'platform': 'android'}));
  }

  static Future<void> unregisterToken(String token) async {
    await _api.safeCall(() => _api.dio.delete('/device-tokens', data: {'token': token}));
  }
}
