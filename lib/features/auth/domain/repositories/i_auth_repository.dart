import '../models/auth_user_bootstrap.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';

abstract class IAuthRepository {
  Future<UserProfile?> getCurrentUser();
  Future<AuthUserBootstrap> fetchUserBootstrap();
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserProfile> signInWithMagicQr({
    required String email,
    required String token,
  });

  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  });
  Future<void> signOut();
  Future<UserProfile> updateProfile(UserProfile profile);
  Future<void> updatePassword(String newPassword);
  Future<void> sendPasswordResetEmail(String email);
  Future<Map<String, dynamic>> provisionPrivilegedUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? branchId,
  });
}
