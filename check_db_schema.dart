import "package:supabase/supabase.dart";

void main() async {
  final supabaseUrl = "https://jprscnyqjkzlofzfaarw.supabase.co";
  final supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpwcnNjbnlxamt6bG9memZhYXJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyMzUyMjksImV4cCI6MjEwMTgxMTIyOX0.BH2ZkP2jjP1nWpiNvPPpk11VmWYMK54xymNxvt15_zc";

  final client = SupabaseClient(supabaseUrl, supabaseKey);

  try {
    final res = await client.from('profiles').select().limit(1);
    print("Profiles columns: ${res.first.keys.toList()}");
  } catch (e) {
    print("Error profiles: $e");
  }

  try {
    final res = await client.from('students').select().limit(1);
    print("Students columns: ${res.first.keys.toList()}");
  } catch (e) {
    print("Error students: $e");
  }

  try {
    final res = await client.from('payments').select().limit(1);
    print("Payments columns: ${res.first.keys.toList()}");
  } catch (e) {
    print("Error payments: $e");
  }
}
