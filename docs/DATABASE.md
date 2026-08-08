# Database Architecture & Entity Specifications (docs/DATABASE.md)

## 1. Migration Policy
- `20260807000001_initial_schema.sql`: **FROZEN**.
- `20260807000002_academy_foundation.sql`: **FROZEN**.
- `20260807000003_foundation_corrections.sql`: **FROZEN**.
- `20260807000004_foundation_consistency.sql`: **FROZEN**.
- `20260807000005_temporal_assignment_integrity.sql`: **FROZEN**.
- `20260807000006_auth_authorization_integration.sql`: **FROZEN**.
- `20260807000007_auth_hardening.sql`: **FROZEN**.
- `20260807000008_academy_core.sql`: Active migration implementing `groups.max_capacity`, atomic concurrency-safe enrollment RPC, schedule conflict RPC, and dashboard summary aggregates.

---

## 2. Temporal Exclusion Constraint Architecture (ADR-014)

### Primary Teacher Overlap Prevention
To prevent multiple primary teachers from being assigned to the same group for overlapping time periods, `public.group_teachers` enforces a PostgreSQL GiST Exclusion Constraint using `btree_gist`:

```sql
ALTER TABLE public.group_teachers
    ADD CONSTRAINT exclude_overlapping_primary_teachers
    EXCLUDE USING gist (
        group_id WITH =,
        daterange(
            effective_from,
            CASE
                WHEN effective_to IS NULL THEN 'infinity'::date
                ELSE effective_to + 1
            END,
            '[)'
        ) WITH &&
    )
    WHERE (is_primary = true);
```

---

## 3. Atomic Concurrency-Safe Capacity Enforcement (Phase 4)
- **RPC Function:** `public.enroll_student_in_group(p_student_id UUID, p_group_id UUID)`
- **Concurrency Strategy:** Row-level locking via `SELECT max_capacity, status FROM public.groups WHERE id = p_group_id FOR UPDATE`.
- **Overbooking Guard:** Rejects transaction with `SQLSTATE 54000` if active enrollments $\ge$ `max_capacity`.

---

## 4. SECURITY DEFINER Helper Function Audit

| Function Name | Purpose | SECURITY DEFINER | EXECUTE Privilege | Uses `auth.uid()` |
| :--- | :--- | :---: | :---: | :---: |
| `current_user_role()` | Resolves authenticated user role | YES | `authenticated` | YES |
| `current_user_branch_id()` | Resolves authenticated user branch | YES | `authenticated` | YES |
| `is_admin_or_super()` | Checks admin/super_admin role | YES | `authenticated` | YES |
| `is_super_admin()` | Checks super_admin role | YES | `authenticated` | YES |
| `has_permission(perm_code)` | Evaluates 5-stage permission precedence | YES | `authenticated` | YES |
| `get_current_user_bootstrap()` | Startup session payload | YES | `authenticated` | YES |
| `complete_privileged_user_profile()` | Trusted server profile setup | YES | `authenticated`, `service_role` | YES |
| `enroll_student_in_group()` | Atomic capacity-safe enrollment | YES | `authenticated` | YES |
| `validate_and_create_schedule()` | Schedule conflict validation | YES | `authenticated` | YES |
| `get_academy_core_summary()` | Aggregate metrics summary | YES | `authenticated` | YES |

---

## 5. Runtime Verification Results

- **Verification Status:** `ACADEMY CORE VERIFICATION: PASS`
- **Verification Date:** 2026-08-07
- **Migrations Applied:** 00001 through 00008 (ALL PASS)
- **pgTAP Database Test Suite:** **38 / 38 PASS** (0 Failed)
- **Flutter Analyzer Result:** 0 issues found (`flutter analyze`)
- **Flutter Test Suite:** **25 / 25 PASS** (`flutter test`)
