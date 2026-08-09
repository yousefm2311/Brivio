param(
  [Parameter(Mandatory = $true)]
  [string] $DatabaseUrl
)

$ErrorActionPreference = "Stop"

$migrations = @(
  "supabase/migrations/20260807000023_smart_study_workspace.sql",
  "supabase/migrations/20260807000024_code_gamification_runtime.sql"
)

foreach ($migration in $migrations) {
  Write-Host "Applying $migration"
  if (Get-Command psql -ErrorAction SilentlyContinue) {
    Get-Content -Raw $migration | psql $DatabaseUrl -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) {
      throw "psql failed while applying $migration"
    }
  } else {
    Get-Content -Raw $migration | docker run --rm -i postgres:16-alpine `
      psql $DatabaseUrl -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) {
      throw "Docker psql failed while applying $migration"
    }
  }
}

Write-Host "Production migrations applied."
