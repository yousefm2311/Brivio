import "package:supabase/supabase.dart";
import "dart:io";

void main() async {
  final supabaseUrl = "https://jprscnyqjkzlofzfaarw.supabase.co";
  final supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpwcnNjbnlxamt6bG9memZhYXJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyMzUyMjksImV4cCI6MjEwMTgxMTIyOX0.BH2ZkP2jjP1nWpiNvPPpk11VmWYMK54xymNxvt15_zc";

  final client = SupabaseClient(supabaseUrl, supabaseKey);

  try {
    print("Reading SQL file...");
    final sql = File('C:/Users/Yousef/.gemini/antigravity/brain/6089111a-28ea-4072-8650-d1e8ef8e97f2/scratch/fix_reset_logic.sql').readAsStringSync();
    print("Executing SQL patch...");
    final res = await client.rpc("exec_sql", params: {"query": sql});
    print("Result: $res");
  } catch (e) {
    print("Error: $e");
  }
}
