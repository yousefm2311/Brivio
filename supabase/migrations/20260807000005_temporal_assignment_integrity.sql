-- Migration: 20260807000005_temporal_assignment_integrity.sql
-- Description: Group Teacher Temporal Assignment Exclusion Constraint & Date Boundary Integrity

-- 1. Enable btree_gist extension for composite scalar + daterange exclusion constraints
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 2. Add CHECK constraint on effective date boundaries
ALTER TABLE public.group_teachers
    ADD CONSTRAINT check_group_teacher_dates
    CHECK (effective_to IS NULL OR effective_to >= effective_from);

-- 3. Drop flawed time-dependent partial unique index from migration 00004
DROP INDEX IF EXISTS public.idx_single_active_primary_teacher;

-- 4. Create proper Temporal Exclusion Constraint for Primary Teachers
-- Date semantics: effective_from (inclusive), effective_to (inclusive).
-- Represented as normalized half-open daterange: [effective_from, COALESCE(effective_to + 1, 'infinity'))
-- Enforces zero overlapping primary teacher periods for a group while permitting past/future assignments and multiple co-teachers.
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

-- 5. Re-verify Explicit UNIQUE Ordering Indexes for Curriculum Hierarchy
CREATE UNIQUE INDEX IF NOT EXISTS idx_semesters_subject_order
    ON public.semesters(subject_id, order_number);

CREATE UNIQUE INDEX IF NOT EXISTS idx_units_semester_order
    ON public.units(semester_id, order_number);

CREATE UNIQUE INDEX IF NOT EXISTS idx_lessons_unit_order
    ON public.lessons(unit_id, order_number);

CREATE UNIQUE INDEX IF NOT EXISTS idx_resources_lesson_order
    ON public.lesson_resources(lesson_id, order_number);
