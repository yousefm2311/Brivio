import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_application_1/core/errors/failures.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_profile.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_role.dart';
import 'package:flutter_application_1/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:flutter_application_1/features/profile/presentation/viewmodels/profile_viewmodel.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late ProfileViewModel viewModel;

  final initialUser = UserProfile(
    id: 'user-1',
    email: 'test@academy.com',
    fullName: 'Initial Name',
    role: UserRole.student,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    viewModel = ProfileViewModel(mockAuthRepository, initialUser);
    registerFallbackValue(initialUser);
  });

  group('ProfileViewModel Unit Tests', () {
    test('initial state contains given user profile', () {
      expect(viewModel.currentProfile, initialUser);
      expect(viewModel.state.status, ProfileStatus.initial);
    });

    test(
      'updateProfileDetails updates profile on repository success',
      () async {
        final updatedUser = initialUser.copyWith(fullName: 'Updated Name');

        when(
          () => mockAuthRepository.updateProfile(any()),
        ).thenAnswer((_) async => updatedUser);

        await viewModel.updateProfileDetails(fullName: 'Updated Name');

        expect(viewModel.state.status, ProfileStatus.success);
        expect(viewModel.currentProfile?.fullName, 'Updated Name');
      },
    );

    test('updatePassword enforces minimum 6 character length', () async {
      await viewModel.updatePassword('123');

      expect(viewModel.state.status, ProfileStatus.error);
      expect(viewModel.state.failure, isA<ValidationFailure>());
    });

    test('updatePassword calls auth repository when valid', () async {
      when(
        () => mockAuthRepository.updatePassword('validPassword123'),
      ).thenAnswer((_) async {});

      await viewModel.updatePassword('validPassword123');

      expect(viewModel.state.status, ProfileStatus.success);
      verify(
        () => mockAuthRepository.updatePassword('validPassword123'),
      ).called(1);
    });
  });
}
