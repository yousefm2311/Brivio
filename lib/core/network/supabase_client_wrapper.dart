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

  /// Refreshes the auth session before database calls when the JWT is close to
  /// expiry. Supabase normally auto-refreshes, but foreground resumes and long
  /// lesson sessions can still hit PostgREST with an expired token.
  Future<void> ensureFreshSession() async {
    final session = _client.auth.currentSession;
    if (session == null) return;

    final expiresAt = session.expiresAt;
    if (expiresAt == null) return;

    final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final shouldRefresh = expiresAtDate.isBefore(
      DateTime.now().add(const Duration(minutes: 2)),
    );
    if (!shouldRefresh) return;

    await _client.auth.refreshSession().timeout(const Duration(seconds: 10));
  }

  Future<T> withFreshSession<T>(
    Future<T> Function(SupabaseClient client) run,
  ) async {
    await ensureFreshSession();
    return run(_client);
  }

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
