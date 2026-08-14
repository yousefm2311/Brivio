import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/auth_user_bootstrap.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/user_role.dart';
import '../../domain/repositories/i_auth_repository.dart';

class SupabaseAuthRepository implements IAuthRepository {
  final SupabaseClientWrapper _clientWrapper;

  SupabaseAuthRepository(this._clientWrapper);

  supabase.SupabaseClient get _client => _clientWrapper.client;

  @override
  Future<UserProfile?> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (response == null) return null;

      return UserProfile.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch user profile: ${e.toString()}',
      );
    }
  }

  @override
  Future<AuthUserBootstrap> fetchUserBootstrap() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure(message: 'Unauthenticated session');
      }

      final response = await _client.rpc('get_current_user_bootstrap');
      if (response == null) {
        throw const DatabaseFailure(message: 'Bootstrap payload returned null');
      }

      final jsonMap = Map<String, dynamic>.from(response as Map);
      return AuthUserBootstrap.fromJson(jsonMap);
    } on supabase.AuthException catch (e) {
      throw AuthFailure(message: e.message);
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw UnexpectedFailure(
        message: 'Failed to load user bootstrap: ${e.toString()}',
      );
    }
  }

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthFailure(
          message: 'Invalid credentials or sign in failed.',
        );
      }

      final profile = await getCurrentUser();
      if (profile == null) {
        throw const AuthFailure(
          message: 'User profile not found after sign in.',
        );
      }

      return profile;
    } on supabase.AuthException catch (e) {
      throw AuthFailure(message: e.message);
    } catch (e) {
      throw UnexpectedFailure(message: 'Sign in failed: ${e.toString()}');
    }
  }

  @override
  Future<UserProfile> signInWithMagicQr({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: supabase.OtpType.magiclink,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthFailure(message: 'Invalid or expired QR code.');
      }

      final profile = await getCurrentUser();
      if (profile == null) {
        throw const AuthFailure(
          message: 'User profile not found after sign in.',
        );
      }

      return profile;
    } on supabase.AuthException catch (e) {
      throw AuthFailure(message: e.message);
    } catch (e) {
      throw UnexpectedFailure(message: 'QR Sign in failed: ${e.toString()}');
    }
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Public self-registration ALWAYS creates student role
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': UserRole.student.toDbValue()},
      );

      final user = response.user;
      if (user == null) {
        throw const AuthFailure(message: 'Sign up failed.');
      }

      final profile = await getCurrentUser();
      if (profile == null) {
        return UserProfile(
          id: user.id,
          email: email,
          fullName: fullName,
          role: UserRole.student,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      return profile;
    } on supabase.AuthException catch (e) {
      throw AuthFailure(message: e.message);
    } catch (e) {
      throw UnexpectedFailure(message: 'Sign up failed: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on supabase.AuthException catch (e) {
      throw AuthFailure(message: e.message);
    } catch (e) {
      throw UnexpectedFailure(message: 'Sign out failed: ${e.toString()}');
    }
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null || user.id != profile.id) {
        throw const AuthFailure(message: 'Unauthorized profile update');
      }

      final updatePayload = {
        'full_name': profile.fullName,
        'avatar_url': profile.avatarUrl,
        'phone_number': profile.phoneNumber,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('profiles')
          .update(updatePayload)
          .eq('id', profile.id)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw UnexpectedFailure(
        message: 'Profile update failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
    } on supabase.AuthException catch (e) {
      throw AuthFailure(message: e.message);
    } catch (e) {
      throw UnexpectedFailure(
        message: 'Password update failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on supabase.AuthException catch (e) {
      throw AuthFailure(message: e.message);
    } catch (e) {
      throw UnexpectedFailure(
        message: 'Password reset failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> provisionPrivilegedUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? branchId,
  }) async {
    try {
      // Invoke trusted Supabase Edge Function boundary
      final response = await _client.functions.invoke(
        'provision-user',
        body: {
          'email': email,
          'fullName': fullName,
          'role': role.toDbValue(),
          'branchId': branchId,
        },
      );

      if (response.status != 200) {
        final errBody = response.data as Map<String, dynamic>?;
        throw AuthFailure(
          message: errBody?['error'] ?? 'Privileged provisioning failed',
        );
      }

      return Map<String, dynamic>.from(response.data as Map);
    } on supabase.FunctionException catch (e) {
      throw AuthFailure(
        message: e.reasonPhrase ?? 'Edge Function execution error',
      );
    } catch (e) {
      throw UnexpectedFailure(
        message: 'Privileged provisioning failed: ${e.toString()}',
      );
    }
  }
}
