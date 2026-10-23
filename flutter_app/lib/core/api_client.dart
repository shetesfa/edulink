import 'package:dio/dio.dart';
import 'api_config.dart';
import 'secure_storage.dart';

/// A simple, uniform result wrapper - every API call resolves to this,
/// so screens never need try/catch scattered everywhere.
class ApiResult<T> {
  final bool success;
  final T? data;
  final String message;

  ApiResult({required this.success, this.data, this.message = ''});
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.baseUrl = ApiConfig.baseUrl;
        final token = await SecureStorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // A 401 means the token is invalid/expired - clear it so the app
        // knows to send the user back to the login screen.
        if (error.response?.statusCode == 401) {
          await SecureStorageService.clearToken();
        }
        handler.next(error);
      },
    ));
  }

  /// Wraps any Dio call and always returns a clean ApiResult, whether the
  /// backend responded with an error JSON or the request failed entirely
  /// (e.g. no internet) - callers never have to guess which happened.
  Future<ApiResult<Map<String, dynamic>>> safeCall(
    Future<Response> Function() call,
  ) async {
    try {
      final response = await call();
      final body = response.data as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] ?? true,
        data: body,
        message: body['message'] ?? '',
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map<String, dynamic>) {
        return ApiResult(
          success: false,
          data: body,
          message: _friendlyErrorMessage(body, e.response?.statusCode),
        );
      }
      if (e.response?.statusCode == 401) {
        return ApiResult(success: false, message: 'Your session has expired. Please sign in again.');
      }
      if (e.response?.statusCode == 403) {
        return ApiResult(success: false, message: 'You do not have permission to do this.');
      }
      if (e.response?.statusCode != null) {
        return ApiResult(success: false, message: 'The service could not complete that request. Please try again.');
      }
      // Provide a helpful network connection error message detailing the target URL
      final currentUrl = ApiConfig.baseUrl;
      return ApiResult(
        success: false,
        message: 'Could not connect to server at ($currentUrl). Make sure your server is running and phone is on the same Wi-Fi.',
      );
    } catch (e) {
      return ApiResult(success: false, message: 'Unexpected error: $e');
    }
  }

  String _friendlyErrorMessage(Map<String, dynamic> body, int? statusCode) {
    if (statusCode == 401) return 'Your session has expired. Please sign in again.';
    if (statusCode == 403) return 'You do not have permission to do this.';

    final errors = body['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty && value.first.toString().trim().isNotEmpty) {
          return value.first.toString();
        }
      }
    }

    final message = body['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    return statusCode != null && statusCode >= 500
        ? 'The server had a temporary problem. Please try again.'
        : 'We could not complete that request. Please try again.';
  }
}
