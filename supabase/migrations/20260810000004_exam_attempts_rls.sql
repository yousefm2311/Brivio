-- Migration: 20260810000004_exam_attempts_rls.sql
-- Description: Add missing Row Level Security policies for exam_attempts so students can view their own attempts and teachers can view their students' attempts.

DROP POLICY IF EXISTS "Exam attempts viewable by self and teachers" ON public.exam_attempts;
CREATE POLICY "Exam attempts viewable by self and teachers" ON public.exam_attempts FOR SELECT TO authenticated USING (
    public.is_admin_or_super() OR 
    (
        -- Student can view their own attempts
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = exam_attempts.student_id AND s.profile_id = auth.uid())
    ) OR 
    (
        -- Teachers can view attempts for exams in their groups
        EXISTS (
            SELECT 1 FROM public.exams ex 
            WHERE ex.id = exam_attempts.exam_id AND public.current_teacher_assigned_to_group(ex.group_id)
        )
    )
);

DROP POLICY IF EXISTS "Homework submissions viewable by self and teachers" ON public.homework_submissions;
CREATE POLICY "Homework submissions viewable by self and teachers" ON public.homework_submissions FOR SELECT TO authenticated USING (
    public.is_admin_or_super() OR 
    (
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = homework_submissions.student_id AND s.profile_id = auth.uid())
    ) OR 
    (
        EXISTS (
            SELECT 1 FROM public.homework hw 
            WHERE hw.id = homework_submissions.homework_id AND public.current_teacher_assigned_to_group(hw.group_id)
        )
    )
);

DROP POLICY IF EXISTS "Exam answers viewable by self and teachers" ON public.exam_answers;
CREATE POLICY "Exam answers viewable by self and teachers" ON public.exam_answers FOR SELECT TO authenticated USING (
    public.is_admin_or_super() OR 
    EXISTS (
        SELECT 1 FROM public.exam_attempts ea 
        WHERE ea.id = exam_answers.attempt_id AND (
            EXISTS (SELECT 1 FROM public.students s WHERE s.id = ea.student_id AND s.profile_id = auth.uid()) OR
            EXISTS (SELECT 1 FROM public.exams ex WHERE ex.id = ea.exam_id AND public.current_teacher_assigned_to_group(ex.group_id))
        )
    )
);
