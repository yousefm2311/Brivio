import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

void main() async {
  final supabaseUrl = 'https://jprscnyqjkzlofzfaarw.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpwcnNjbnlxamt6bG9memZhYXJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyMzUyMjksImV4cCI6MjEwMTgxMTIyOX0.BH2ZkP2jjP1nWpiNvPPpk11VmWYMK54xymNxvt15_zc';

  final client = SupabaseClient(supabaseUrl, supabaseKey);

  print('Fetching teacher_study_annotations...');
  final res = await client.from('teacher_study_annotations').select();
  print('Result: $res');
}
