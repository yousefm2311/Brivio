import "package:supabase_flutter/supabase_flutter.dart";
import "dart:convert";

void main() async {
  final supabaseUrl = "https://jprscnyqjkzlofzfaarw.supabase.co";
  final supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpwcnNjbnlxamt6bG9memZhYXJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyMzUyMjksImV4cCI6MjEwMTgxMTIyOX0.BH2ZkP2jjP1nWpiNvPPpk11VmWYMK54xymNxvt15_zc";

  final client = SupabaseClient(supabaseUrl, supabaseKey);

  try {
    print("Executing SQL patch for QR token...");
    final res = await client.rpc("exec_sql", params: {"query": "ALTER FUNCTION public.create_account_login_qr(UUID) SET search_path = public, extensions;"});
    print("Result: \$res");
  } catch (e) {
    print("Error: \$e");
  }
}

