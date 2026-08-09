# Production Supabase Setup

The app is configured for production through `--dart-define`; Supabase keys are
not stored in source code.

## Run Against Production

```powershell
.\scripts\run_production_web.ps1 -SupabaseAnonKey "<SUPABASE_ANON_KEY>"
```

The script uses:

```text
https://jprscnyqjkzlofzfaarw.supabase.co
```

## Apply Database Migrations

The anon key cannot run DDL or create tables. To apply migrations to the hosted
Supabase database, use the database connection string from:

Supabase Dashboard -> Project Settings -> Database -> Connection string

Then run:

```powershell
.\scripts\apply_production_migrations.ps1 -DatabaseUrl "<DATABASE_URL>"
```

The script applies:

```text
supabase/migrations/20260807000023_smart_study_workspace.sql
supabase/migrations/20260807000024_code_gamification_runtime.sql
```

It uses local `psql` when installed, otherwise it runs `psql` through Docker.

## Required Production Data

No demo data is seeded. Before real usage, create actual records for:

- branches
- subjects
- groups
- profiles and user roles
- students, parents, teachers, staff
- teacher group assignments
- student enrollments
- subscription plans, if billing is used
