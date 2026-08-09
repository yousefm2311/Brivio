import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../logging/app_logger.dart';

/// Wrapper around Supabase client providing centralized access and initialization.
class SupabaseClientWrapper {
  final SupabaseClient _client;

  SupabaseClientWrapper(this._client);

  SupabaseClient get client => _client;
  GoTrueClient get auth => _client.auth;

  /// Check if a valid auth session exists
  bool get isAuthenticated => _client.auth.currentSession != null;

  /// Current authenticated user ID if logged in
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Factory initializer for application startup
  static Future<SupabaseClientWrapper> initialize({
    required String url,
    required String anonKey,
  }) async {
    AppLogger.info('Initializing Supabase client...');
    final supabase = await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
    ).timeout(const Duration(seconds: 15));
    AppLogger.info('Supabase client initialization completed.');
    return SupabaseClientWrapper(supabase.client);
  }
}
