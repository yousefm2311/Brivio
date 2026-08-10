-- Migration: 20260810000001_assessment_rls_policies.sql
-- Description: Add missing Row Level Security policies for Exams and Homework to allow Teachers and Students to view and manage them.

-- 1. Policies for `exams`
DROP POLICY IF EXISTS "Exams viewable by authorized users" ON public.exams;
CREATE POLICY "Exams viewable by authorized users" ON public.exams FOR SELECT TO authenticated USING (
    public.is_admin_or_super() OR 
    public.has_permission('exams.view') OR 
    EXISTS (
        SELECT 1 FROM public.groups g WHERE g.id = exams.group_id AND (
            public.current_teacher_assigned_to_group(g.id) OR
            EXISTS (SELECT 1 FROM public.enrollments e JOIN public.students s ON s.id = e.student_id WHERE e.group_id = g.id AND s.profile_id = auth.uid() AND e.status = 'active')
        )
    )
);

DROP POLICY IF EXISTS "Exams manageable by authorized users" ON public.exams;
CREATE POLICY "Exams manageable by authorized users" ON public.exams FOR ALL TO authenticated USING (
    public.is_admin_or_super() OR 
    public.has_permission('exams.manage') OR 
    public.current_teacher_assigned_to_group(group_id)
) WITH CHECK (
    public.is_admin_or_super() OR 
    public.has_permission('exams.manage') OR 
    public.current_teacher_assigned_to_group(group_id)
);


-- 2. Policies for `homework`
DROP POLICY IF EXISTS "Homework viewable by authorized users" ON public.homework;
CREATE POLICY "Homework viewable by authorized users" ON public.homework FOR SELECT TO authenticated USING (
    public.is_admin_or_super() OR 
    public.has_permission('homework.view') OR 
    EXISTS (
        SELECT 1 FROM public.groups g WHERE g.id = homework.group_id AND (
            public.current_teacher_assigned_to_group(g.id) OR
            EXISTS (SELECT 1 FROM public.enrollments e JOIN public.students s ON s.id = e.student_id WHERE e.group_id = g.id AND s.profile_id = auth.uid() AND e.status = 'active')
        )
    )
);

DROP POLICY IF EXISTS "Homework manageable by authorized users" ON public.homework;
CREATE POLICY "Homework manageable by authorized users" ON public.homework FOR ALL TO authenticated USING (
    public.is_admin_or_super() OR 
    public.has_permission('homework.manage') OR 
    public.current_teacher_assigned_to_group(group_id)
) WITH CHECK (
    public.is_admin_or_super() OR 
    public.has_permission('homework.manage') OR 
    public.current_teacher_assigned_to_group(group_id)
);


-- 3. Policies for `exam_questions`
DROP POLICY IF EXISTS "Exam questions viewable by authorized users" ON public.exam_questions;
CREATE POLICY "Exam questions viewable by authorized users" ON public.exam_questions FOR SELECT TO authenticated USING (
    public.is_admin_or_super() OR 
    public.has_permission('exams.view') OR 
    EXISTS (
        SELECT 1 FROM public.exams ex WHERE ex.id = exam_questions.exam_id AND (
            public.current_teacher_assigned_to_group(ex.group_id) OR
            EXISTS (SELECT 1 FROM public.enrollments e JOIN public.students s ON s.id = e.student_id WHERE e.group_id = ex.group_id AND s.profile_id = auth.uid() AND e.status = 'active')
        )
    )
);

DROP POLICY IF EXISTS "Exam questions manageable by authorized users" ON public.exam_questions;
CREATE POLICY "Exam questions manageable by authorized users" ON public.exam_questions FOR ALL TO authenticated USING (
    public.is_admin_or_super() OR 
    public.has_permission('exams.manage') OR 
    EXISTS (
        SELECT 1 FROM public.exams ex WHERE ex.id = exam_questions.exam_id AND public.current_teacher_assigned_to_group(ex.group_id)
    )
) WITH CHECK (
    public.is_admin_or_super() OR 
    public.has_permission('exams.manage') OR 
    EXISTS (
        SELECT 1 FROM public.exams ex WHERE ex.id = exam_questions.exam_id AND public.current_teacher_assigned_to_group(ex.group_id)
    )
);


-- 4. Policies for `homework_questions`
DROP POLICY IF EXISTS "Homework questions viewable by authorized users" ON public.homework_questions;
CREATE POLICY "Homework questions viewable by authorized users" ON public.homework_questions FOR SELECT TO authenticated USING (
    public.is_admin_or_super() OR 
    public.has_permission('homework.view') OR 
    EXISTS (
        SELECT 1 FROM public.homework hw WHERE hw.id = homework_questions.homework_id AND (
            public.current_teacher_assigned_to_group(hw.group_id) OR
            EXISTS (SELECT 1 FROM public.enrollments e JOIN public.students s ON s.id = e.student_id WHERE e.group_id = hw.group_id AND s.profile_id = auth.uid() AND e.status = 'active')
        )
    )
);

DROP POLICY IF EXISTS "Homework questions manageable by authorized users" ON public.homework_questions;
CREATE POLICY "Homework questions manageable by authorized users" ON public.homework_questions FOR ALL TO authenticated USING (
    public.is_admin_or_super() OR 
    public.has_permission('homework.manage') OR 
    EXISTS (
        SELECT 1 FROM public.homework hw WHERE hw.id = homework_questions.homework_id AND public.current_teacher_assigned_to_group(hw.group_id)
    )
) WITH CHECK (
    public.is_admin_or_super() OR 
    public.has_permission('homework.manage') OR 
    EXISTS (
        SELECT 1 FROM public.homework hw WHERE hw.id = homework_questions.homework_id AND public.current_teacher_assigned_to_group(hw.group_id)
    )
);
