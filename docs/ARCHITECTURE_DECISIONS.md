# Architectural Decision Records (docs/ARCHITECTURE_DECISIONS.md)

## Summary of Locked Decisions

| ADR | Topic | Decision Summary |
| :--- | :--- | :--- |
| **ADR-001** | Identity Model | 1-to-1 extension: `public.profiles.id = auth.users.id` |
| **ADR-002** | Role vs Permission | 6 Canonical Roles as baseline profile; granular permissions for operations |
| **ADR-003** | Branch Membership | Single primary `branch_id` on profile; extensible via junction tables for staff/teachers |
| **ADR-004** | RLS Authorization | Recursion-safe SECURITY DEFINER helpers with search_path pinned to public |
| **ADR-005** | Signup Security | Public signup defaults ALWAYS to `student`; privileged roles provisioned by admins |
| **ADR-006** | Code Playground Scope | Initial production languages locked to Python & C++ |
| **ADR-007** | Migration Freeze | Migrations 00001 through 00004 frozen; future DB changes ship as incremental migrations |
| **ADR-008** | Permission Precedence | 5-stage deterministic evaluation: super_admin -> user DENY -> user GRANT -> role baseline -> default DENY |
| **ADR-009** | Subject Ownership | Subjects are global catalog entities; Groups represent branch delivery |
| **ADR-010** | Group Instructors | `group_teachers` is sole canonical source of truth; redundant `groups.teacher_id` eliminated |
| **ADR-011** | Identity Security Helpers | RLS security helpers derive identity internally via `auth.uid()` |
| **ADR-012** | Curriculum Hierarchy | Normalized Subject -> Semester -> Unit -> Lesson -> Resource; redundant unit.subject_id eliminated |
| **ADR-013** | Primary Teacher Rule | Partial unique index replaced by temporal EXCLUDE constraint (ADR-014) |
| **ADR-014** | Temporal Overlap Model | GiST Exclusion Constraint on `group_teachers` prevents overlapping primary teacher dateranges |

---

## ADR-001: Profile / Auth Identity Model
### Status: Accepted & Locked.
`public.profiles` shares the exact UUID issued by `auth.users` (`profiles.id = auth.users.id`).

---

## ADR-002: Role and Permission Model
### Status: Accepted & Locked.
6 Canonical Roles (`super_admin`, `admin`, `staff`, `teacher`, `parent`, `student`) provide baseline access. Granular capability permissions extend staff/teacher capabilities.

---

## ADR-003: Branch Membership Model
### Status: Accepted & Locked.
Primary branch on profile (`profiles.branch_id`). Cross-branch group enrollments & multi-branch operations supported via junction tables.

---

## ADR-004: RLS Authorization Strategy & Recursion Safety
### Status: Accepted & Locked.
Recursion-safe PostgreSQL functions with `SECURITY DEFINER SET search_path = public`. RLS UPDATE policy on `public.profiles` includes strict `WITH CHECK` clause preventing self-mutation.

---

## ADR-005: Public Signup & Privileged Role Provisioning
### Status: Accepted & Locked.
`public.handle_new_user()` trigger **ALWAYS** forces `role = 'student'::user_role` for public signups.

---

## ADR-006: Code Playground Initial Language Scope
### Status: Accepted & Locked.
Initial production scope strictly locked to **Python** and **C++**.

---

## ADR-007: Migration Freeze Policy
### Status: Accepted & Locked.
Migrations 00001 through 00004 are **FROZEN**. Incremental schema changes ship via sequential migration files (`20260807000005_temporal_assignment_integrity.sql`).

---

## ADR-008: Deterministic User Permission Override Precedence Model
### Status: Accepted & Locked.
5-Stage Deterministic Evaluation in `public.has_permission(perm_code TEXT)`:
1. `super_admin` override $\to$ **GRANT (TRUE)**
2. Explicit User DENY (`user_permissions.effect = 'deny'`) $\to$ **DENY (FALSE)**
3. Explicit User GRANT (`user_permissions.effect = 'grant'`) $\to$ **GRANT (TRUE)**
4. Baseline Role Permission (`role_permissions`) $\to$ **GRANT (TRUE)**
5. Default Fallback $\to$ **DENY (FALSE)**

---

## ADR-009: Subject Ownership as Global Academic Catalog
### Status: Accepted & Locked.
`subjects` are global catalog entities; `groups` represent branch-specific delivery of a subject.

---

## ADR-010: Group Instructor Assignment Strategy (`group_teachers`)
### Status: Accepted & Locked.
`public.group_teachers` is the sole canonical source of truth for group instructor assignments. Redundant `groups.teacher_id` column has been dropped.

---

## ADR-011: Identity-Bound Security Helper Functions
### Status: Accepted & Locked.
All RLS security helpers derive identity internally via `auth.uid()`. EXECUTE privileges are revoked from `PUBLIC` and granted exclusively to `authenticated`.

---

## ADR-012: Normalized Curriculum Hierarchy & Scoped Ordering
### Status: Accepted & Locked.
- Canonical hierarchy: `Subject` $\to$ `Semester` $\to$ `Unit` $\to$ `Lesson` $\to$ `Lesson Resource`.
- `units.semester_id` is mandatory FK to `semesters.id`.
- Ordering uniqueness is strictly scoped: `semesters(subject_id, order_number)`, `units(semester_id, order_number)`, `lessons(unit_id, order_number)`.

---

## ADR-013 & ADR-014: Temporal Exclusion Constraint Model for Primary Teachers

### Status: Accepted & Locked.

### Context
Time-dependent expressions like `CURRENT_DATE` inside partial index predicates are invalid because PostgreSQL index membership does not dynamically update as time advances.

### Chosen Approach
1. **Extension:** Enable `btree_gist` extension in migration `00005`.
2. **Exclusion Constraint:** Add `exclude_overlapping_primary_teachers` EXCLUDE constraint using GiST on `public.group_teachers`:
   ```sql
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
   ) WHERE (is_primary = true)
   ```
3. **Date Semantics:** `effective_from` (inclusive) and `effective_to` (inclusive). Normalized into half-open range `[effective_from, COALESCE(effective_to + 1, 'infinity'))`.
4. **CHECK Constraint:** Enforce `effective_to IS NULL OR effective_to >= effective_from`.
5. **Multi-Instructor Support:** Exclusion applies strictly when `is_primary = true`. Multiple co-teachers (`is_primary = false`) can have overlapping assignment periods.
