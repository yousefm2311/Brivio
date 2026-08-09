param(
  [Parameter(Mandatory = $true)]
  [string] $SupabaseAnonKey,

  [string] $SupabaseUrl = "https://jprscnyqjkzlofzfaarw.supabase.co"
)

flutter run -d chrome `
  --dart-define="SUPABASE_URL=$SupabaseUrl" `
  --dart-define="SUPABASE_ANON_KEY=$SupabaseAnonKey"
