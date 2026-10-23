import 'package:flutter_test/flutter_test.dart';
import 'package:edulink_app/models/user.dart';
import 'package:edulink_app/core/api_config.dart';

void main() {
  test('AppUser json parsing test', () {
    final json = {
      'id': 1,
      'first_name': 'Abebe',
      'last_name': 'Bikila',
      'email': 'abebe@example.com',
      'role': {'name': 'student'},
      'is_active': 1
    };

    final user = AppUser.fromJson(json);

    expect(user.id, 1);
    expect(user.fullName, 'Abebe Bikila');
    expect(user.roleName, 'student');
    expect(user.isActive, isTrue);
  });

  test('ApiConfig baseUrl default test', () {
    expect(ApiConfig.baseUrl, contains('http'));
  });
}
