-- Migration: 20260807000003_foundation_corrections.sql
-- Description: Foundation Integrity Corrections (Permission Overrides, Identity Helpers, Partial Unique Indexes, Group Teachers Junction, and Security Policy Reconciliations)

-- 1. Permission Override Effect Type
CREATE TYPE permission_effect AS ENUM ('grant', 'deny');

ALTER TABLE public.user_permissions
    ADD COLUMN effect permission_effect NOT NULL DEFAULT 'grant';

-- 2. Deterministic Permission Evaluation Helper Function
-- Precedence: 1. super_admin -> 2. Explicit User DENY -> 3. Explicit User GRANT -> 4. Role Baseline Permission -> 5. Default DENY
CREATE OR REPLACE FUNCTION public.has_permission(perm_code TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    u_id UUID := auth.uid();
    user_override permission_effect;
    role_has_perm BOOLEAN := false;
BEGIN
    IF u_id IS NULL THEN
        RETURN false;
    END IF;

    -- 1. Super Admin bypass
    IF public.is_super_admin() THEN
        RETURN true;
    END IF;

    -- 2 & 3. Check explicit user permission override
    SELECT up.effect INTO user_override
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = u_id AND p.code = perm_code;

    IF user_override = 'deny' THEN
        RETURN false;
    ELSIF user_override = 'grant' THEN
        RETURN true;
    END IF;

    -- 4. Check baseline role permission
    SELECT EXISTS (
        SELECT 1
        FROM public.role_permissions rp
        JOIN public.roles r ON r.id = rp.role_id
        JOIN public.permissions p ON p.id = rp.permission_id
        WHERE r.name = public.current_user_role()::text AND p.code = perm_code
    ) INTO role_has_perm;

    RETURN role_has_perm;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Revoke default public execution; grant to authenticated users only
REVOKE EXECUTE ON FUNCTION public.has_permission(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_permission(TEXT) TO authenticated;

-- 3. Identity-Bound Security Helper Functions (auth.uid() internal derivation)
CREATE OR REPLACE FUNCTION public.current_student_id()
RETURNS UUID AS $$
DECLARE
    s_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN RETURN NULL; END IF;
    SELECT id INTO s_id FROM public.students WHERE profile_id = auth.uid();
    RETURN s_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_parent_id()
RETURNS UUID AS $$
DECLARE
    p_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN RETURN NULL; END IF;
    SELECT id INTO p_id FROM public.parents WHERE profile_id = auth.uid();
    RETURN p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_teacher_id()
RETURNS UUID AS $$
DECLARE
    t_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN RETURN NULL; END IF;
    SELECT id INTO t_id FROM public.teachers WHERE profile_id = auth.uid();
    RETURN t_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_parent_has_student(target_student_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    p_id UUID;
BEGIN
    p_id := public.current_parent_id();
    IF p_id IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.parent_students
        WHERE parent_id = p_id AND student_id = target_student_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_student_enrolled_in_group(target_group_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    s_id UUID;
BEGIN
    s_id := public.current_student_id();
    IF s_id IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.enrollments
        WHERE student_id = s_id AND group_id = target_group_id AND status = 'active'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_teacher_assigned_to_group(target_group_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    t_id UUID;
BEGIN
    t_id := public.current_teacher_id();
    IF t_id IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.groups
        WHERE id = target_group_id AND teacher_id = t_id
    ) OR EXISTS (
        SELECT 1 FROM public.group_teachers
        WHERE group_id = target_group_id AND teacher_id = t_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Revoke public execution on security helpers
REVOKE EXECUTE ON FUNCTION public.current_student_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_parent_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_teacher_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_parent_has_student(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_student_enrolled_in_group(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_teacher_assigned_to_group(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.current_student_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_parent_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_teacher_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_parent_has_student(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_student_enrolled_in_group(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_teacher_assigned_to_group(UUID) TO authenticated;

-- 4. Group Teachers Junction Table (Flexible co-instructor & historical assignment)
CREATE TABLE IF NOT EXISTS public.group_teachers (
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'co_teacher',
    is_primary BOOLEAN NOT NULL DEFAULT false,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, teacher_id)
);

ALTER TABLE public.group_teachers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Group teachers viewable by authenticated users"
    ON public.group_teachers FOR SELECT TO authenticated USING (true);

-- 5. Partial Unique Indexes
-- Drop standard unique constraint on active enrollments if exists and replace with partial index
ALTER TABLE public.enrollments DROP CONSTRAINT IF EXISTS unique_active_student_group_enrollment;

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_enrollment
    ON public.enrollments(student_id, group_id)
    WHERE status = 'active';

-- Partial Index: At most ONE primary guardian per student
CREATE UNIQUE INDEX IF NOT EXISTS idx_single_primary_parent
    ON public.parent_students(student_id)
    WHERE is_primary = true;

-- 6. Ordering & Publication Constraints
CREATE UNIQUE INDEX IF NOT EXISTS idx_units_order ON public.units(subject_id, order_number);
CREATE UNIQUE INDEX IF NOT EXISTS idx_lessons_order ON public.lessons(unit_id, order_number);
CREATE UNIQUE INDEX IF NOT EXISTS idx_resources_order ON public.lesson_resources(lesson_id, order_number);

ALTER TABLE public.lessons
    ADD CONSTRAINT check_lesson_publication CHECK (status != 'published' OR published_at IS NOT NULL);

-- 7. Reconcile RLS Policies with Granular Permission Helpers & Identity Helpers

-- Students Table RLS
DROP POLICY IF EXISTS "Students viewable by self, linked parents, staff, admins" ON public.students;
DROP POLICY IF EXISTS "Admins and Staff manage students" ON public.students;

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

CREATE POLICY "Students managed by authorized permission holders" ON public.students
    FOR ALL TO authenticated USING (public.has_permission('students.manage')) WITH CHECK (public.has_permission('students.manage'));

-- Parents Table RLS
DROP POLICY IF EXISTS "Parents viewable by self, staff, admins" ON public.parents;
DROP POLICY IF EXISTS "Admins and Staff manage parents" ON public.parents;

CREATE POLICY "Parents viewable by self or authorized permission holders" ON public.parents
    FOR SELECT TO authenticated USING (
        profile_id = auth.uid() OR public.has_permission('parents.view')
    );

CREATE POLICY "Parents managed by authorized permission holders" ON public.parents
    FOR ALL TO authenticated USING (public.has_permission('parents.manage')) WITH CHECK (public.has_permission('parents.manage'));

-- Groups RLS
DROP POLICY IF EXISTS "Groups viewable by enrolled students, assigned teachers, staff, admins" ON public.groups;
DROP POLICY IF EXISTS "Admins and Staff manage groups" ON public.groups;

CREATE POLICY "Groups viewable by participants or permission holders" ON public.groups
    FOR SELECT TO authenticated USING (
        public.current_teacher_assigned_to_group(id)
        OR public.current_student_enrolled_in_group(id)
        OR public.has_permission('groups.view')
    );

CREATE POLICY "Groups managed by authorized permission holders" ON public.groups
    FOR ALL TO authenticated USING (public.has_permission('groups.manage')) WITH CHECK (public.has_permission('groups.manage'));

-- Enrollments RLS
DROP POLICY IF EXISTS "Enrollments viewable by student, linked parent, teacher, staff, admin" ON public.enrollments;
DROP POLICY IF EXISTS "Admins and Staff manage enrollments" ON public.enrollments;

CREATE POLICY "Enrollments viewable by participant or permission holders" ON public.enrollments
    FOR SELECT TO authenticated USING (
        student_id = public.current_student_id()
        OR public.current_parent_has_student(student_id)
        OR public.current_teacher_assigned_to_group(group_id)
        OR public.has_permission('enrollments.view')
    );

CREATE POLICY "Enrollments managed by authorized permission holders" ON public.enrollments
    FOR ALL TO authenticated USING (public.has_permission('enrollments.manage')) WITH CHECK (public.has_permission('enrollments.manage'));
