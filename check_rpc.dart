import "package:supabase/supabase.dart";

void main() async {
  final supabaseUrl = "https://jprscnyqjkzlofzfaarw.supabase.co";
  final supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpwcnNjbnlxamt6bG9memZhYXJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyMzUyMjksImV4cCI6MjEwMTgxMTIyOX0.BH2ZkP2jjP1nWpiNvPPpk11VmWYMK54xymNxvt15_zc";

  final client = SupabaseClient(supabaseUrl, supabaseKey);

  try {
    final res = await client.rpc('get_admin_analytics', params: {
      'period_start': '2020-01-01',
      'period_end': '2030-01-01',
    });
    print("Analytics RPC Result: ${res}");
  } catch (e) {
    print("Error RPC: ${e}");
  }
}
