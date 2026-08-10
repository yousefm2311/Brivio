-- Migration: 20260810000000_fix_groups_rls_and_is_teacher.sql
-- Description: Fix lingering RLS policies and helpers that still rely on the dropped groups.teacher_id column

-- 1. Fix is_teacher_of_group helper
CREATE OR REPLACE FUNCTION public.is_teacher_of_group(teacher_user_id UUID, target_group_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    t_id UUID;
    is_assigned BOOLEAN := false;
BEGIN
    t_id := public.get_teacher_id(teacher_user_id);
    IF t_id IS NULL THEN RETURN false; END IF;
    SELECT EXISTS (
        SELECT 1 FROM public.group_teachers
        WHERE group_id = target_group_id 
          AND teacher_id = t_id
          AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
    ) INTO is_assigned;
    RETURN is_assigned;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. Drop the old Groups RLS policy which explicitly queries teacher_id
DROP POLICY IF EXISTS "Groups viewable by enrolled students, assigned teachers, staff, admins" ON public.groups;

-- 3. Drop the old Schedules RLS policy and recreate it (using the fixed is_teacher_of_group)
DROP POLICY IF EXISTS "Schedules viewable by group participants, staff, admins" ON public.schedules;
CREATE POLICY "Schedules viewable by group participants, staff, admins" ON public.schedules FOR SELECT TO authenticated USING (
    public.is_student_enrolled_in_group(auth.uid(), group_id)
    OR public.is_teacher_of_group(auth.uid(), group_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

-- Note: The groups RLS policy was already replaced by "Groups viewable by participants or permission holders" in 20260807000004
