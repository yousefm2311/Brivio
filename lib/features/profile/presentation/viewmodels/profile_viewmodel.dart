import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/models/user_profile.dart';
import '../../../auth/domain/repositories/i_auth_repository.dart';

enum ProfileStatus { initial, loading, success, error }

class ProfileState {
  final ProfileStatus status;
  final UserProfile? profile;
  final Failure? failure;
  final String? message;

  const ProfileState({
    required this.status,
    this.profile,
    this.failure,
    this.message,
  });

  factory ProfileState.initial(UserProfile? profile) =>
      ProfileState(status: ProfileStatus.initial, profile: profile);
  factory ProfileState.loading(UserProfile? profile) =>
      ProfileState(status: ProfileStatus.loading, profile: profile);
  factory ProfileState.success(UserProfile profile, String message) =>
      ProfileState(
        status: ProfileStatus.success,
        profile: profile,
        message: message,
      );
  factory ProfileState.error(UserProfile? profile, Failure failure) =>
      ProfileState(
        status: ProfileStatus.error,
        profile: profile,
        failure: failure,
      );
}

class ProfileViewModel extends ChangeNotifier {
  final IAuthRepository _authRepository;
  ProfileState _state;

  ProfileViewModel(this._authRepository, UserProfile? initialProfile)
    : _state = ProfileState.initial(initialProfile);

  ProfileState get state => _state;
  UserProfile? get currentProfile => _state.profile;

  Future<void> updateProfileDetails({
    required String fullName,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final active = _state.profile;
    if (active == null) return;

    _state = ProfileState.loading(active);
    notifyListeners();

    try {
      final updated = active.copyWith(
        fullName: fullName.trim(),
        phoneNumber: phoneNumber?.trim(),
        avatarUrl: avatarUrl?.trim(),
        updatedAt: DateTime.now(),
      );

      final result = await _authRepository.updateProfile(updated);
      _state = ProfileState.success(result, 'Profile updated successfully');
    } on Failure catch (failure) {
      _state = ProfileState.error(active, failure);
    } catch (e) {
      _state = ProfileState.error(
        active,
        UnexpectedFailure(message: e.toString()),
      );
    }
    notifyListeners();
  }

  Future<void> updatePassword(String newPassword) async {
    final active = _state.profile;
    if (newPassword.trim().length < 6) {
      _state = ProfileState.error(
        active,
        const ValidationFailure(
          message: 'Password must be at least 6 characters long',
        ),
      );
      notifyListeners();
      return;
    }

    _state = ProfileState.loading(active);
    notifyListeners();

    try {
      await _authRepository.updatePassword(newPassword);
      if (active != null) {
        _state = ProfileState.success(active, 'Password updated successfully');
      }
    } on Failure catch (failure) {
      _state = ProfileState.error(active, failure);
    } catch (e) {
      _state = ProfileState.error(
        active,
        UnexpectedFailure(message: e.toString()),
      );
    }
    notifyListeners();
  }
}
