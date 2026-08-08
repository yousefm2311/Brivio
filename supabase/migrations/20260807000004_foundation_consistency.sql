-- Migration: 20260807000004_foundation_consistency.sql
-- Description: Foundation Consistency Lock (Normalized Curriculum Hierarchy, Canonical Group Teacher Model, and RLS Helper Updates)

-- 1. Curriculum Hierarchy Normalization
-- Hierarchy: Subject -> Semester -> Unit -> Lesson -> Resource
-- Add order_number to semesters
ALTER TABLE public.semesters
    ADD COLUMN IF NOT EXISTS order_number INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_semesters_order
    ON public.semesters(subject_id, order_number);

-- Drop redundant subject_id from units; semester_id becomes mandatory FK
ALTER TABLE public.units DROP CONSTRAINT IF EXISTS unique_unit_subject_code CASCADE;
DROP INDEX IF EXISTS public.idx_units_order;

ALTER TABLE public.units
    DROP COLUMN IF EXISTS subject_id CASCADE;

ALTER TABLE public.units
    ALTER COLUMN semester_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_units_semester_order
    ON public.units(semester_id, order_number);

-- 2. Group Teacher Single Source of Truth
-- Remove groups.teacher_id to establish group_teachers as the single canonical assignment source
DROP INDEX IF EXISTS public.idx_groups_teacher_id;

ALTER TABLE public.groups
    DROP COLUMN IF EXISTS teacher_id CASCADE;

-- Primary teacher temporal exclusion constraint handled in migration 20260807000005 via GiST EXCLUDE constraint

-- 3. Re-implement current_teacher_assigned_to_group Helper to use canonical group_teachers timeline
CREATE OR REPLACE FUNCTION public.current_teacher_assigned_to_group(target_group_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    t_id UUID;
BEGIN
    t_id := public.current_teacher_id();
    IF t_id IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.group_teachers
        WHERE group_id = target_group_id
          AND teacher_id = t_id
          AND effective_from <= CURRENT_DATE
          AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.current_teacher_assigned_to_group(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_teacher_assigned_to_group(UUID) TO authenticated;

-- 4. Reconcile RLS Policies to use canonical group_teachers model

-- Reconcile Students RLS
DROP POLICY IF EXISTS "Students viewable by authorized roles or linked identity" ON public.students;

CREATE POLICY "Students viewable by authorized roles or linked identity" ON public.students
    FOR SELECT TO authenticated USING (
        profile_id = auth.uid()
        OR public.current_parent_has_student(id)
        OR public.has_permission('students.view')
        OR EXISTS (
            SELECT 1 FROM public.enrollments e
            WHERE e.student_id = students.id AND public.current_teacher_assigned_to_group(e.group_id)
        )
    );

-- Reconcile Groups RLS
DROP POLICY IF EXISTS "Groups viewable by participants or permission holders" ON public.groups;

CREATE POLICY "Groups viewable by participants or permission holders" ON public.groups
    FOR SELECT TO authenticated USING (
        public.current_teacher_assigned_to_group(id)
        OR public.current_student_enrolled_in_group(id)
        OR public.has_permission('groups.view')
    );

-- Reconcile Enrollments RLS
DROP POLICY IF EXISTS "Enrollments viewable by participant or permission holders" ON public.enrollments;

CREATE POLICY "Enrollments viewable by participant or permission holders" ON public.enrollments
    FOR SELECT TO authenticated USING (
        student_id = public.current_student_id()
        OR public.current_parent_has_student(student_id)
        OR public.current_teacher_assigned_to_group(group_id)
        OR public.has_permission('enrollments.view')
    );
