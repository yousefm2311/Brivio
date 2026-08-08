import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';

/// Centralized application environment and Supabase configuration.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:15431',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  /// Dynamically resolved Supabase URL handling Android loopback (10.0.2.2) automatically
  static String get effectiveSupabaseUrl {
    const rawUrl = supabaseUrl;
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
