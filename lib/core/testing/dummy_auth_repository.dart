import '../../core/security/permission.dart';
import '../../features/auth/domain/models/auth_user_bootstrap.dart';
import '../../features/auth/domain/models/user_profile.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';

class DummyAuthRepository implements IAuthRepository {
  UserProfile? _currentUser;

  DummyAuthRepository.unauthenticated() : _currentUser = null;

  DummyAuthRepository([UserProfile? initialUser])
    : _currentUser =
          initialUser ??
          UserProfile(
            id: 'dummy-student-id',
            email: 'student@academy.com',
            fullName: 'Test Student',
            role: UserRole.student,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

  @override
  Future<UserProfile?> getCurrentUser() async => _currentUser;

  @override
  Future<AuthUserBootstrap> fetchUserBootstrap() async {
    final user =
        _currentUser ??
        UserProfile(
          id: 'dummy-student-id',
          email: 'student@academy.com',
          fullName: 'Test Student',
          role: UserRole.student,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    return AuthUserBootstrap(
      profile: user,
      role: user.role,
      primaryBranchId: user.branchId,
      accountStatus: AccountStatus.active,
      effectivePermissions: const [
        Permission.studentsView,
        Permission.curriculumView,
      ],
      studentId: 'dummy-student-domain-id',
    );
  }

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final profile = UserProfile(
      id: 'mock-uid-123',
      email: email,
      fullName: 'Mock User',
      role: UserRole.student,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _currentUser = profile;
    return profile;
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final profile = UserProfile(
      id: 'mock-uid-new',
      email: email,
      fullName: fullName,
      role: UserRole.student,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _currentUser = profile;
    return profile;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    _currentUser = profile;
    return profile;
  }

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<Map<String, dynamic>> provisionPrivilegedUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? branchId,
  }) async {
    return {
      'success': true,
      'user_id': 'provisioned-uuid-123',
      'email': email,
      'role': role.toDbValue(),
      'message': 'User provisioned successfully',
    };
  }
}
