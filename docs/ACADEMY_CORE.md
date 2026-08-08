# Academy Core Architecture & Management (docs/ACADEMY_CORE.md)

## 1. Domain Entities & Responsibilities
- **`branches`**: Operational campus locations (`Main Campus`, `North Branch`).
- **`subjects`**: Global academic course catalog (e.g. `Computer Science 101`, `Advanced Physics`).
- **`groups`**: Branch-specific class delivery instances linked to a subject, with configured `max_capacity`.
- **`group_teachers`**: Temporal instructor assignments (`is_primary`, `effective_from`, `effective_to`) governed by PostgreSQL GiST exclusion constraint.
- **`enrollments`**: Student group enrollments managed atomically to prevent capacity overbooking.
- **`schedules`**: Time-slot assignments (`day_of_week`, `start_time`, `end_time`, `location`) governed by schedule conflict validation logic.

---

## 2. Capacity Concurrency Architecture
To prevent overbooking when multiple users enroll concurrently:
- Capacity enforcement relies on PostgreSQL RPC `public.enroll_student_in_group(p_student_id, p_group_id)`.
- The function performs row-level locking on `public.groups` using `SELECT max_capacity, status FROM public.groups WHERE id = p_group_id FOR UPDATE`.
- If `active` enrollments meet or exceed `max_capacity`, the transaction is rolled back with `SQLSTATE 54000 (Group Capacity Exceeded)`.

---

## 3. Schedule Conflict Architecture
Schedule creation/updates invoke `public.validate_and_create_schedule(p_group_id, p_day_of_week, p_start_time, p_end_time, p_location)`:
1. **Time Order Boundary:** Validates `p_end_time > p_start_time` (rejection `SQLSTATE 23514`).
2. **Group Overlap:** Rejects overlapping time slots for the same group on the same day (`SQLSTATE 23505`).
3. **Teacher Overlap:** Resolves active primary teacher and checks for simultaneous schedule conflicts in other groups.
4. **Room Overlap:** Prevents double-booking of identical `location` rooms during overlapping time slots.

---

## 4. Feature Repositories
- [`SupabaseBranchRepository`](file:///f:/flutter_application_1/lib/features/academy/data/repositories/supabase_academy_repositories.dart)
- [`SupabaseSubjectRepository`](file:///f:/flutter_application_1/lib/features/academy/data/repositories/supabase_academy_repositories.dart)
- [`SupabaseGroupRepository`](file:///f:/flutter_application_1/lib/features/academy/data/repositories/supabase_academy_repositories.dart)
- [`SupabaseEnrollmentRepository`](file:///f:/flutter_application_1/lib/features/academy/data/repositories/supabase_academy_repositories.dart)
- [`SupabaseScheduleRepository`](file:///f:/flutter_application_1/lib/features/academy/data/repositories/supabase_academy_repositories.dart)
- [`SupabaseAcademySummaryRepository`](file:///f:/flutter_application_1/lib/features/academy/data/repositories/supabase_academy_repositories.dart)
