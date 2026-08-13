import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failures.dart';

class SupabaseErrorHandler {
  static String parseError(Object error) {
    if (error is Failure) {
      return error.message;
    }

    if (error is AuthException) {
      return _translateAuthError(error.message);
    }

    if (error is PostgrestException) {
      return _translatePostgrestError(error);
    }

    if (error is Exception) {
      final msg = error.toString();
      if (msg.contains('Failed host lookup')) {
        return 'No internet connection. Please check your network and try again.';
      }
      return msg.replaceAll('Exception:', '').trim();
    }

    return 'Unexpected Error: ${error.toString()}';
  }

  static String _translateAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (lower.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password is too weak. Please use a stronger password.';
    }
    return message;
  }

  static String _translatePostgrestError(PostgrestException error) {
    // Check specific constraint codes
    switch (error.code) {
      case '23505': // unique_violation
        return 'This record already exists. Duplicate entries are not allowed.';
      case '23503': // foreign_key_violation
        return 'This record is being used by another part of the system and cannot be deleted or modified right now.';
      case '42P01': // undefined_table
        return 'A database structure is missing. Please contact support or run the database fixes.';
      case '22P02': // invalid_text_representation (e.g. invalid UUID)
        return 'Invalid data format provided. Please ensure all fields are filled correctly.';
      case '42501': // insufficient_privilege
        return 'You do not have permission to perform this action.';
      default:
        // Try to glean from message or details if code is missing or PGRST*
        final text = '${error.message} ${error.details ?? ''}'.toLowerCase();

        if (text.contains('could not find the function')) {
          return 'A required database function is missing. Please run the provided SQL fix script in Supabase.';
        }
        if (text.contains('user with this email already exists')) {
          return 'An account with this email already exists.';
        }

        return 'Database Error: ${error.message}';
    }
  }
}
