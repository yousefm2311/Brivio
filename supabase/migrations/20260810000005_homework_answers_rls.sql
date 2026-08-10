-- Migration: 20260810000005_homework_answers_rls.sql
-- Description: Add missing Row Level Security policies for homework_answers so teachers can fetch student answers.

DROP POLICY IF EXISTS "Homework answers viewable by self and teachers" ON public.homework_answers;
CREATE POLICY "Homework answers viewable by self and teachers" ON public.homework_answers FOR SELECT TO authenticated USING (
    public.is_admin_or_super() OR 
    EXISTS (
        SELECT 1 FROM public.homework_submissions hs 
        WHERE hs.id = homework_answers.submission_id AND (
            EXISTS (SELECT 1 FROM public.students s WHERE s.id = hs.student_id AND s.profile_id = auth.uid()) OR
            EXISTS (SELECT 1 FROM public.homework hw WHERE hw.id = hs.homework_id AND public.current_teacher_assigned_to_group(hw.group_id))
        )
    )
);
