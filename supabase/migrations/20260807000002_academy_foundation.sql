-- Migration: 20260807000002_academy_foundation.sql
-- Description: Complete Academy Database Foundation (Roles, Permissions, Students, Parents, Teachers, Subjects, Groups, Enrollments, Schedules, Curriculum, Storage References, Security Helpers & RLS)

-- 1. Custom Types
CREATE TYPE lesson_type AS ENUM ('video', 'text', 'pdf', 'programming', 'quiz');
CREATE TYPE enrollment_status AS ENUM ('active', 'pending', 'dropped', 'completed');

-- 2. Core Authorization & Granular Permission Tables
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    module TEXT NOT NULL,
    action TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS public.user_permissions (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
    is_granted BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, permission_id)
);

-- 3. Student Domain Table
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_code TEXT UNIQUE NOT NULL,
    birth_date DATE,
    school_name TEXT,
    grade_level TEXT,
    primary_branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Parent Domain & Junction Tables
CREATE TABLE IF NOT EXISTS public.parents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    occupation TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.parent_students (
    parent_id UUID NOT NULL REFERENCES public.parents(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    relationship_type TEXT NOT NULL DEFAULT 'guardian',
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (parent_id, student_id)
);

-- 5. Teacher Domain & Assignment Tables
CREATE TABLE IF NOT EXISTS public.teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    primary_branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    specialization TEXT,
    bio TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Subjects Catalog Table
CREATE TABLE IF NOT EXISTS public.subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    description TEXT,
    bucket TEXT,
    object_path TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.teacher_subjects (
    teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (teacher_id, subject_id)
);

-- 7. Groups (Classes) Table
CREATE TABLE IF NOT EXISTS public.groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE RESTRICT,
    teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
    branch_id UUID NOT NULL REFERENCES public.branches(id) ON DELETE RESTRICT,
    capacity INT NOT NULL DEFAULT 30,
    status TEXT NOT NULL DEFAULT 'active',
    academic_period TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Enrollments Table
CREATE TABLE IF NOT EXISTS public.enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    status enrollment_status NOT NULL DEFAULT 'active',
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_active_student_group_enrollment UNIQUE (student_id, group_id)
);

-- 9. Schedules Table
CREATE TABLE IF NOT EXISTS public.schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    location TEXT,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_schedule_times CHECK (start_time < end_time)
);

-- 10. Curriculum Hierarchy Tables
CREATE TABLE IF NOT EXISTS public.semesters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_semester_dates CHECK (start_date < end_date)
);

CREATE TABLE IF NOT EXISTS public.units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    semester_id UUID REFERENCES public.semesters(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    order_number INT NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_unit_subject_code UNIQUE (subject_id, code)
);

CREATE TABLE IF NOT EXISTS public.lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_id UUID NOT NULL REFERENCES public.units(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    lesson_type lesson_type NOT NULL DEFAULT 'text',
    order_number INT NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.lesson_resources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    resource_type TEXT NOT NULL DEFAULT 'attachment',
    bucket TEXT NOT NULL,
    object_path TEXT NOT NULL,
    order_number INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.lesson_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'in_progress',
    progress_percentage NUMERIC(5,2) NOT NULL DEFAULT 0.00 CHECK (progress_percentage BETWEEN 0 AND 100),
    last_position TEXT,
    time_spent_seconds INT NOT NULL DEFAULT 0,
    completed_at TIMESTAMPTZ,
    last_accessed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_student_lesson_progress UNIQUE (student_id, lesson_id)
);

-- 11. Database Indexes Strategy
CREATE INDEX IF NOT EXISTS idx_students_profile_id ON public.students(profile_id);
CREATE INDEX IF NOT EXISTS idx_students_branch_id ON public.students(primary_branch_id);
CREATE INDEX IF NOT EXISTS idx_parents_profile_id ON public.parents(profile_id);
CREATE INDEX IF NOT EXISTS idx_teachers_profile_id ON public.teachers(profile_id);
CREATE INDEX IF NOT EXISTS idx_teachers_branch_id ON public.teachers(primary_branch_id);
CREATE INDEX IF NOT EXISTS idx_groups_subject_id ON public.groups(subject_id);
CREATE INDEX IF NOT EXISTS idx_groups_teacher_id ON public.groups(teacher_id);
CREATE INDEX IF NOT EXISTS idx_groups_branch_id ON public.groups(branch_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_student_id ON public.enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_group_id ON public.enrollments(group_id);
CREATE INDEX IF NOT EXISTS idx_schedules_group_id ON public.schedules(group_id);
CREATE INDEX IF NOT EXISTS idx_units_subject_id ON public.units(subject_id);
CREATE INDEX IF NOT EXISTS idx_lessons_unit_id ON public.lessons(unit_id);
CREATE INDEX IF NOT EXISTS idx_lesson_progress_student_id ON public.lesson_progress(student_id);
CREATE INDEX IF NOT EXISTS idx_lesson_progress_lesson_id ON public.lesson_progress(lesson_id);

-- 12. Modtime Triggers
CREATE TRIGGER update_students_modtime BEFORE UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_parents_modtime BEFORE UPDATE ON public.parents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_teachers_modtime BEFORE UPDATE ON public.teachers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_subjects_modtime BEFORE UPDATE ON public.subjects FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_groups_modtime BEFORE UPDATE ON public.groups FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_enrollments_modtime BEFORE UPDATE ON public.enrollments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_semesters_modtime BEFORE UPDATE ON public.semesters FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_units_modtime BEFORE UPDATE ON public.units FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_lessons_modtime BEFORE UPDATE ON public.lessons FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_lesson_resources_modtime BEFORE UPDATE ON public.lesson_resources FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 13. Domain Helper Functions (SECURITY DEFINER with search_path = public)
CREATE OR REPLACE FUNCTION public.get_student_id(u_id UUID)
RETURNS UUID AS $$
DECLARE
    s_id UUID;
BEGIN
    SELECT id INTO s_id FROM public.students WHERE profile_id = u_id;
    RETURN s_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_parent_id(u_id UUID)
RETURNS UUID AS $$
DECLARE
    p_id UUID;
BEGIN
    SELECT id INTO p_id FROM public.parents WHERE profile_id = u_id;
    RETURN p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_teacher_id(u_id UUID)
RETURNS UUID AS $$
DECLARE
    t_id UUID;
BEGIN
    SELECT id INTO t_id FROM public.teachers WHERE profile_id = u_id;
    RETURN t_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_parent_of_student(parent_user_id UUID, target_student_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    p_id UUID;
    is_linked BOOLEAN := false;
BEGIN
    p_id := public.get_parent_id(parent_user_id);
    IF p_id IS NULL THEN RETURN false; END IF;
    SELECT EXISTS (
        SELECT 1 FROM public.parent_students
        WHERE parent_id = p_id AND student_id = target_student_id
    ) INTO is_linked;
    RETURN is_linked;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_student_enrolled_in_group(student_user_id UUID, target_group_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    s_id UUID;
    is_enrolled BOOLEAN := false;
BEGIN
    s_id := public.get_student_id(student_user_id);
    IF s_id IS NULL THEN RETURN false; END IF;
    SELECT EXISTS (
        SELECT 1 FROM public.enrollments
        WHERE student_id = s_id AND group_id = target_group_id AND status = 'active'
    ) INTO is_enrolled;
    RETURN is_enrolled;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_teacher_of_group(teacher_user_id UUID, target_group_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    t_id UUID;
    is_assigned BOOLEAN := false;
BEGIN
    t_id := public.get_teacher_id(teacher_user_id);
    IF t_id IS NULL THEN RETURN false; END IF;
    SELECT EXISTS (
        SELECT 1 FROM public.groups
        WHERE id = target_group_id AND teacher_id = t_id
    ) INTO is_assigned;
    RETURN is_assigned;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 14. Enable Row Level Security (RLS) across all Foundation Tables
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.semesters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_progress ENABLE ROW LEVEL SECURITY;

-- 15. RLS Policies

-- Catalog Tables (roles, permissions, subjects, semesters, units, lessons, resources)
CREATE POLICY "Public catalog viewable by authenticated users" ON public.roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Permissions viewable by staff and admins" ON public.permissions FOR SELECT TO authenticated USING (public.current_user_role() IN ('admin', 'staff', 'super_admin'));
CREATE POLICY "Subjects viewable by authenticated users" ON public.subjects FOR SELECT TO authenticated USING (true);
CREATE POLICY "Semesters viewable by authenticated users" ON public.semesters FOR SELECT TO authenticated USING (true);
CREATE POLICY "Units viewable by authenticated users" ON public.units FOR SELECT TO authenticated USING (true);

-- Lessons RLS (Published lessons viewable by enrolled students, assigned teachers, staff, admins)
CREATE POLICY "Lessons viewable by authorized users" ON public.lessons FOR SELECT TO authenticated USING (
    status = 'published' OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
);

CREATE POLICY "Lesson resources viewable by authorized users" ON public.lesson_resources FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.lessons WHERE id = lesson_resources.lesson_id AND (status = 'published' OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')))
);

-- Students Table RLS
CREATE POLICY "Students viewable by self, linked parents, staff, admins" ON public.students FOR SELECT TO authenticated USING (
    profile_id = auth.uid()
    OR public.is_parent_of_student(auth.uid(), id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    OR EXISTS (
        SELECT 1 FROM public.enrollments e
        JOIN public.groups g ON g.id = e.group_id
        WHERE e.student_id = students.id AND g.teacher_id = public.get_teacher_id(auth.uid())
    )
);

-- Parents & Parent-Students Junction RLS
CREATE POLICY "Parents viewable by self, staff, admins" ON public.parents FOR SELECT TO authenticated USING (
    profile_id = auth.uid() OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

CREATE POLICY "Parent-Students junction viewable by linked parent, staff, admins" ON public.parent_students FOR SELECT TO authenticated USING (
    parent_id = public.get_parent_id(auth.uid()) OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

-- Teachers Table RLS
CREATE POLICY "Teachers viewable by authenticated users" ON public.teachers FOR SELECT TO authenticated USING (true);

-- Groups & Schedules RLS
CREATE POLICY "Groups viewable by enrolled students, assigned teachers, staff, admins" ON public.groups FOR SELECT TO authenticated USING (
    teacher_id = public.get_teacher_id(auth.uid())
    OR public.is_student_enrolled_in_group(auth.uid(), id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

CREATE POLICY "Schedules viewable by group participants, staff, admins" ON public.schedules FOR SELECT TO authenticated USING (
    public.is_student_enrolled_in_group(auth.uid(), group_id)
    OR public.is_teacher_of_group(auth.uid(), group_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

-- Enrollments RLS
CREATE POLICY "Enrollments viewable by student, linked parent, teacher, staff, admin" ON public.enrollments FOR SELECT TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
    OR public.is_parent_of_student(auth.uid(), student_id)
    OR public.is_teacher_of_group(auth.uid(), group_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

-- Lesson Progress RLS
CREATE POLICY "Lesson progress viewable and editable by student" ON public.lesson_progress FOR SELECT TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
    OR public.is_parent_of_student(auth.uid(), student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
);

CREATE POLICY "Lesson progress upsert by self student" ON public.lesson_progress FOR ALL TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
) WITH CHECK (
    student_id = public.get_student_id(auth.uid())
);

-- Admin & Staff Management Write Policies
CREATE POLICY "Admins and Staff manage students" ON public.students FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'staff', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));
CREATE POLICY "Admins and Staff manage parents" ON public.parents FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'staff', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));
CREATE POLICY "Admins and Staff manage parent_students" ON public.parent_students FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'staff', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));
CREATE POLICY "Admins and Staff manage teachers" ON public.teachers FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'staff', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));
CREATE POLICY "Admins manage subjects" ON public.subjects FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'super_admin'));
CREATE POLICY "Admins and Staff manage groups" ON public.groups FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'staff', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));
CREATE POLICY "Admins and Staff manage enrollments" ON public.enrollments FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'staff', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));
CREATE POLICY "Admins and Staff manage schedules" ON public.schedules FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'staff', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'staff', 'super_admin'));
CREATE POLICY "Admins and Teachers manage units" ON public.units FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'teacher', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'teacher', 'super_admin'));
CREATE POLICY "Admins and Teachers manage lessons" ON public.lessons FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'teacher', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'teacher', 'super_admin'));
CREATE POLICY "Admins and Teachers manage lesson resources" ON public.lesson_resources FOR ALL TO authenticated USING (public.current_user_role() IN ('admin', 'teacher', 'super_admin')) WITH CHECK (public.current_user_role() IN ('admin', 'teacher', 'super_admin'));
