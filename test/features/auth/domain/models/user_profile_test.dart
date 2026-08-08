import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_profile.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_role.dart';

void main() {
  group('UserProfile Model Tests', () {
    final now = DateTime(2026, 8, 7, 12, 0);
    final json = {
      'id': 'user-123',
      'email': 'test@academy.com',
      'full_name': 'Test User',
      'role': 'student',
      'branch_id': 'branch-456',
      'phone_number': '+1234567890',
      'avatar_url': 'https://example.com/avatar.png',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    test('fromJson deserializes JSON properly', () {
      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.email, 'test@academy.com');
      expect(profile.fullName, 'Test User');
      expect(profile.role, UserRole.student);
      expect(profile.branchId, 'branch-456');
    });

    test('toJson serializes model to DB format', () {
      final profile = UserProfile.fromJson(json);
      final outputJson = profile.toJson();

      expect(outputJson['id'], 'user-123');
      expect(outputJson['email'], 'test@academy.com');
      expect(outputJson['role'], 'student');
    });

    test('copyWith updates properties properly', () {
      final profile = UserProfile.fromJson(json);
      final updated = profile.copyWith(
        fullName: 'Updated Name',
        role: UserRole.teacher,
      );

      expect(updated.fullName, 'Updated Name');
      expect(updated.role, UserRole.teacher);
      expect(updated.id, profile.id);
    });
  });
}
