import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';

/// Centralized application environment and Supabase configuration.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jprscnyqjkzlofzfaarw.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpwcnNjbnlxamt6bG9memZhYXJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyMzUyMjksImV4cCI6MjEwMTgxMTIyOX0.BH2ZkP2jjP1nWpiNvPPpk11VmWYMK54xymNxvt15_zc',
  );

  static const String codeSandboxUrl = String.fromEnvironment(
    'CODE_SANDBOX_URL',
    defaultValue: 'http://127.0.0.1:8787',
  );

  static const String codeSandboxApiKey = String.fromEnvironment(
    'CODE_SANDBOX_API_KEY',
    defaultValue: '',
  );

  static Map<String, String> get codeSandboxHeaders {
    final headers = {'Content-Type': 'application/json'};
    if (codeSandboxApiKey.trim().isNotEmpty) {
      headers['X-Sandbox-Key'] = codeSandboxApiKey.trim();
    }
    return headers;
  }

  /// Dynamically resolved Supabase URL handling Android loopback (10.0.2.2) automatically
  static String get effectiveSupabaseUrl {
    const rawUrl = supabaseUrl;
    if (rawUrl.trim().isEmpty) {
      throw StateError('SUPABASE_URL must be provided with --dart-define.');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (rawUrl.contains('127.0.0.1')) {
        return rawUrl.replaceAll('127.0.0.1', '10.0.2.2');
      }
      if (rawUrl.contains('localhost')) {
        return rawUrl.replaceAll('localhost', '10.0.2.2');
      }
    }
    return rawUrl;
  }

  static String get effectiveCodeSandboxUrl {
    final rawUrl = codeSandboxUrl;
    if (defaultTargetPlatform == TargetPlatform.android &&
        (rawUrl.contains('127.0.0.1') || rawUrl.contains('localhost'))) {
      return rawUrl
          .replaceFirst('127.0.0.1', '10.0.2.2')
          .replaceFirst('localhost', '10.0.2.2');
    }
    return rawUrl;
  }

  static String get effectiveSupabaseAnonKey {
    const rawKey = supabaseAnonKey;
    if (rawKey.trim().isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY must be provided with --dart-define.',
      );
    }
    return rawKey;
  }

  /// Safely print debug diagnostics in development without leaking secrets.
  static void printSafeDiagnostics() {
    try {
      final uri = Uri.parse(effectiveSupabaseUrl);
      final envName = kDebugMode ? 'development' : 'production';
      AppLogger.info(
        'Supabase client configured: ${uri.scheme}://${uri.host}:${uri.port} (Environment: $envName)',
      );
    } catch (_) {
      AppLogger.info(
        'Supabase client configured (Environment: ${kDebugMode ? "development" : "production"})',
      );
    }
  }
}
