import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient('https://xxx.supabase.co', 'xxx');
  // I need to use query_db.dart which already has the client set up!
}
