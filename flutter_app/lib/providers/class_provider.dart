import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/school_class.dart';

class ClassProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  int? currentUserId;
  List<SchoolClass> teaching = [];
  List<SchoolClass> enrolled = [];
  bool isLoading = false;

  List<SchoolClass> get allMyClasses => [...teaching, ...enrolled];

  Future<void> loadClasses([int? userId]) async {
    if (userId != null) currentUserId = userId;
    isLoading = true;
    notifyListeners();

    final result = await _api.safeCall(() => _api.dio.get('/classes'));
    if (result.success && result.data != null) {
      final data = result.data!['data'] ?? result.data;
      if (data is Map<String, dynamic>) {
        final teachingRaw = data['teaching'] ?? data['classes_taught'];
        final enrolledRaw = data['enrolled'] ?? data['classes_enrolled'];

        if (teachingRaw is List) {
          teaching = teachingRaw.map((c) => SchoolClass.fromJson(c as Map<String, dynamic>)).toList();
        }
        if (enrolledRaw is List) {
          enrolled = enrolledRaw.map((c) => SchoolClass.fromJson(c as Map<String, dynamic>)).toList();
        }

        final allRaw = data['classes'] ?? data['all'];
        if (allRaw is List) {
          final all = allRaw.map((c) => SchoolClass.fromJson(c as Map<String, dynamic>)).toList();
          if (currentUserId != null) {
            teaching = all.where((c) => c.teacherId == currentUserId).toList();
            enrolled = all.where((c) => c.teacherId != currentUserId).toList();
          } else {
            teaching = all;
          }
        }
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<ApiResult<Map<String, dynamic>>> joinClass(String joinCode) async {
    final result = await _api.safeCall(() => _api.dio.post('/classes/join', data: {'join_code': joinCode}));
    if (result.success) await loadClasses();
    return result;
  }

  Future<ApiResult<Map<String, dynamic>>> createClass({
    required String name,
    String? subject,
    String? description,
  }) async {
    final result = await _api.safeCall(() => _api.dio.post('/classes', data: {
          'name': name,
          'subject': subject,
          'description': description,
        }));
    if (result.success) await loadClasses();
    return result;
  }
}
