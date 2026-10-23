import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../core/local_database.dart';
import '../core/push_notification_service.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? pendingVerificationEmail;

  /// Restores session on app startup and prevents auto-logout when app is closed
  Future<void> tryRestoreSession() async {
    try {
      if (kIsWeb) {
        final uri = Uri.base;
        final tokenParam = uri.queryParameters['token'];
        final userParam = uri.queryParameters['user'];

        if (tokenParam != null && tokenParam.isNotEmpty) {
          await SecureStorageService.saveToken(tokenParam);
          if (userParam != null && userParam.isNotEmpty) {
            try {
              final userMap = jsonDecode(userParam) as Map<String, dynamic>;
              currentUser = AppUser.fromJson(userMap);
              await LocalDatabase.putCache('current_user', jsonEncode(currentUser!.toJson()));
            } catch (_) {}
          }
          status = AuthStatus.authenticated;
          notifyListeners();
          return;
        }
      }

      final token = await SecureStorageService.getToken();
      final cachedUserJson = await LocalDatabase.getCache('current_user');

      if (token == null || token.isEmpty) {
        status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      if (cachedUserJson != null && cachedUserJson.isNotEmpty) {
        try {
          currentUser = AppUser.fromJson(jsonDecode(cachedUserJson));
          status = AuthStatus.authenticated;
          notifyListeners();
          PushNotificationService.initialize();
        } catch (_) {}
      } else {
        status = AuthStatus.authenticated;
      }

      // Background refresh - if offline or unreachable, keep offline session active
      final result = await _api.safeCall(() => _api.dio.get('/auth/me'));
      if (result.success && result.data != null) {
        final userData = result.data!['data']?['user'] ?? result.data!['user'];
        if (userData != null) {
          final user = AppUser.fromJson(userData as Map<String, dynamic>);
          currentUser = user;
          await LocalDatabase.putCache('current_user', jsonEncode(user.toJson()));
          status = AuthStatus.authenticated;
          notifyListeners();
        }
      } else if (result.message.contains('401') || result.data?['message']?.toString().contains('Unauthenticated') == true) {
        await logout();
      } else {
        if (currentUser != null) {
          status = AuthStatus.authenticated;
          notifyListeners();
        }
      }
    } catch (e) {
      if (currentUser != null) {
        status = AuthStatus.authenticated;
      } else {
        status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    }
  }

  void updateCurrentUser(AppUser user) {
    currentUser = user;
    LocalDatabase.putCache('current_user', jsonEncode(user.toJson()));
    notifyListeners();
  }

  Future<ApiResult<Map<String, dynamic>>> updateProfileName(String firstName, String lastName) async {
    final result = await _api.safeCall(() => _api.dio.post('/auth/profile', data: {
          'first_name': firstName,
          'last_name': lastName,
        }));
    if (result.success && result.data != null) {
      final userData = result.data!['data']?['user'] ?? result.data!['user'];
      if (userData != null) {
        final user = AppUser.fromJson(userData as Map<String, dynamic>);
        updateCurrentUser(user);
      }
    }
    return result;
  }

  Future<ApiResult<Map<String, dynamic>>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String role = 'student',
  }) async {
    final result = await _api.safeCall(() => _api.dio.post('/auth/register', data: {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'role': role,
        }));

    if (result.success) {
      pendingVerificationEmail = email;
    }
    return result;
  }

  Future<ApiResult<Map<String, dynamic>>> verifyEmail(String email, String otp) async {
    final result = await _api.safeCall(() => _api.dio.post('/auth/verify-email', data: {
          'email': email,
          'otp': otp,
        }));

    if (result.success) {
      await _persistLogin(result.data!);
    }
    return result;
  }

  Future<ApiResult<Map<String, dynamic>>> resendVerificationOtp(String email) {
    return _api.safeCall(() => _api.dio.post('/auth/resend-verification-otp', data: {'email': email}));
  }

  Future<ApiResult<Map<String, dynamic>>> login(String email, String password) async {
    final result = await _api.safeCall(() => _api.dio.post('/auth/login', data: {
          'email': email,
          'password': password,
        }));

    if (result.success) {
      await _persistLogin(result.data!);
    } else if (result.data?['data']?['requires_verification'] == true) {
      pendingVerificationEmail = email;
    }
    return result;
  }

  Future<ApiResult<Map<String, dynamic>>> sendLoginOtp(String email) {
    return _api.safeCall(() => _api.dio.post('/auth/send-login-otp', data: {'email': email}));
  }

  Future<ApiResult<Map<String, dynamic>>> verifyLoginOtp(String email, String otp) async {
    final result = await _api.safeCall(() => _api.dio.post('/auth/verify-login-otp', data: {
          'email': email,
          'otp': otp,
        }));

    if (result.success && result.data != null) {
      final persisted = await _persistLogin(result.data!);
      if (!persisted) {
        return ApiResult(
          success: false,
          message: 'Could not restore user session data from server response.',
        );
      }
    }
    return result;
  }

  Future<ApiResult<Map<String, dynamic>>> forgotPassword(String email) {
    return _api.safeCall(() => _api.dio.post('/auth/forgot-password', data: {'email': email}));
  }

  Future<ApiResult<Map<String, dynamic>>> resetPassword(String email, String token, String password) {
    return _api.safeCall(() => _api.dio.post('/auth/reset-password', data: {
          'email': email,
          'token': token,
          'password': password,
          'password_confirmation': password,
        }));
  }

  Future<void> loginWithGoogleResponse(Map<String, dynamic> responseBody) async {
    await _persistLogin(responseBody);
  }

  Future<ApiResult<Map<String, dynamic>>> updateProfileDetails({
    required String firstName,
    required String lastName,
    String? username,
    String? filePath,
  }) async {
    final formMap = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      if (username != null && username.isNotEmpty) 'username': username,
    };

    if (filePath != null && filePath.isNotEmpty) {
      formMap['profile_photo'] = await MultipartFile.fromFile(filePath);
    }

    final result = await _api.safeCall(() => _api.dio.post(
          '/auth/profile',
          data: FormData.fromMap(formMap),
        ));

    if (result.success && result.data != null) {
      final userMap = result.data!['data']?['user'] ?? result.data!['user'];
      if (userMap != null) {
        currentUser = AppUser.fromJson(userMap as Map<String, dynamic>);
        await LocalDatabase.putCache('current_user', jsonEncode(currentUser!.toJson()));
        notifyListeners();
      }
    }
    return result;
  }

  Future<ApiResult<Map<String, dynamic>>> updateRole(String role) async {
    if (currentUser == null) {
      return ApiResult(success: false, message: 'Your session has expired. Please sign in again.');
    }
    currentUser = currentUser!.copyWith(roleName: role);
    await LocalDatabase.putCache('current_user', jsonEncode(currentUser!.toJson()));
    notifyListeners();
    final result = await _api.safeCall(() => _api.dio.post('/auth/update-role', data: {'role': role}));
    if (result.success && result.data?['data']?['user'] is Map<String, dynamic>) {
      currentUser = AppUser.fromJson(result.data!['data']['user'] as Map<String, dynamic>);
      await LocalDatabase.putCache('current_user', jsonEncode(currentUser!.toJson()));
      notifyListeners();
    }
    return result;
  }

  Future<bool> _persistLogin(Map<String, dynamic> responseBody) async {
    try {
      final data = (responseBody['data'] is Map<String, dynamic>) ? responseBody['data'] : responseBody;
      final token = (data['token'] ?? responseBody['token']) as String?;
      final userMap = (data['user'] ?? responseBody['user']) as Map<String, dynamic>?;

      if (token == null || userMap == null) {
        debugPrint('Failed to extract login session data: $responseBody');
        return false;
      }

      final user = AppUser.fromJson(userMap);

      await SecureStorageService.saveToken(token);
      await LocalDatabase.putCache('current_user', jsonEncode(user.toJson()));

      currentUser = user;
      status = AuthStatus.authenticated;
      notifyListeners();

      try {
        PushNotificationService.initialize();
      } catch (e) {
        debugPrint('PushNotificationService init error: $e');
      }
      return true;
    } catch (e) {
      debugPrint('Error in _persistLogin: $e');
      return false;
    }
  }

  Future<void> logout() async {
    // Local logout must never depend on the server being online.  Previously
    // this awaited the API request first, leaving the user stuck on the
    // settings page while a disconnected server timed out.
    await SecureStorageService.clearToken();
    await LocalDatabase.putCache('current_user', '');

    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
