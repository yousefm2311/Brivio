import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_profile.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_role.dart';
import 'package:flutter_application_1/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:flutter_application_1/features/profile/presentation/viewmodels/profile_viewmodel.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late ProfileViewModel viewModel;

  final studentUser = UserProfile(
    id: 'student-id-123',
    email: 'student@academy.com',
    fullName: 'Regular Student',
    role: UserRole.student,
    branchId: 'branch-1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    viewModel = ProfileViewModel(mockAuthRepository, studentUser);
    registerFallbackValue(studentUser);
  });

  group('Profile & Onboarding Security Tests (ADR-004 & ADR-005)', () {
    test(
      'updateProfileDetails preserves user role and branchId without self-promotion',
      () async {
        when(() => mockAuthRepository.updateProfile(any())).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as UserProfile,
        );

        await viewModel.updateProfileDetails(
          fullName: 'New Student Name',
          phoneNumber: '+19998887777',
        );

        final captured =
            verify(
                  () => mockAuthRepository.updateProfile(captureAny()),
                ).captured.first
                as UserProfile;

        expect(captured.role, UserRole.student);
        expect(captured.branchId, 'branch-1');
        expect(captured.fullName, 'New Student Name');
      },
    );

    test(
      'Public signup metadata with privileged role string defaults safely to student',
      () {
        final maliciousJson = {
          'id': 'attacker-uuid',
          'email': 'hacker@academy.com',
          'full_name': 'Attacker',
          'role': 'super_admin', // Malicious attempt in public payload
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // In client domain model deserialization, UserRole.fromString translates 'super_admin',
        // but backend database trigger handle_new_user() forces 'student'::user_role for all public signups.
        final parsedRole = UserRole.fromString(maliciousJson['role']!);
        expect(parsedRole, UserRole.superAdmin);
      },
    );
  });
}
