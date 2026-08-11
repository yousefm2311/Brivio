-- Fix teacher_study_annotations and teacher_study_pdf_drawings schemas

-- 1. Alter teacher_study_annotations to reference teachers(id) instead of profiles(id)
ALTER TABLE public.teacher_study_annotations DROP CONSTRAINT IF EXISTS teacher_study_annotations_teacher_id_fkey;
ALTER TABLE public.teacher_study_annotations ADD CONSTRAINT teacher_study_annotations_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teachers(id) ON DELETE CASCADE;

-- 2. Fix RLS policies for teacher_study_annotations
DROP POLICY IF EXISTS "Teachers can insert their own annotations" ON public.teacher_study_annotations;
CREATE POLICY "Teachers can insert their own annotations"
    ON public.teacher_study_annotations FOR INSERT TO authenticated
    WITH CHECK (teacher_id = public.get_teacher_id(auth.uid()));

DROP POLICY IF EXISTS "Teachers can update their own annotations" ON public.teacher_study_annotations;
CREATE POLICY "Teachers can update their own annotations"
    ON public.teacher_study_annotations FOR UPDATE TO authenticated
    USING (teacher_id = public.get_teacher_id(auth.uid())) WITH CHECK (teacher_id = public.get_teacher_id(auth.uid()));

DROP POLICY IF EXISTS "Teachers can delete their own annotations" ON public.teacher_study_annotations;
CREATE POLICY "Teachers can delete their own annotations"
    ON public.teacher_study_annotations FOR DELETE TO authenticated
    USING (teacher_id = public.get_teacher_id(auth.uid()));

-- 3. Alter teacher_study_pdf_drawings to reference teachers(id) instead of profiles(id)
ALTER TABLE public.teacher_study_pdf_drawings DROP CONSTRAINT IF EXISTS teacher_study_pdf_drawings_teacher_id_fkey;
ALTER TABLE public.teacher_study_pdf_drawings ADD CONSTRAINT teacher_study_pdf_drawings_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teachers(id) ON DELETE CASCADE;

-- 4. Fix RLS policies for teacher_study_pdf_drawings
DROP POLICY IF EXISTS "Teachers can insert their own drawings" ON public.teacher_study_pdf_drawings;
CREATE POLICY "Teachers can insert their own drawings"
    ON public.teacher_study_pdf_drawings FOR INSERT TO authenticated
    WITH CHECK (teacher_id = public.get_teacher_id(auth.uid()));

DROP POLICY IF EXISTS "Teachers can update their own drawings" ON public.teacher_study_pdf_drawings;
CREATE POLICY "Teachers can update their own drawings"
    ON public.teacher_study_pdf_drawings FOR UPDATE TO authenticated
    USING (teacher_id = public.get_teacher_id(auth.uid())) WITH CHECK (teacher_id = public.get_teacher_id(auth.uid()));

DROP POLICY IF EXISTS "Teachers can delete their own drawings" ON public.teacher_study_pdf_drawings;
CREATE POLICY "Teachers can delete their own drawings"
    ON public.teacher_study_pdf_drawings FOR DELETE TO authenticated
    USING (teacher_id = public.get_teacher_id(auth.uid()));

-- 5. Fix get_student_teacher_study_boards RPC
CREATE OR REPLACE FUNCTION public.get_student_teacher_study_boards()
RETURNS TABLE (
  id UUID, title TEXT, description TEXT, lesson_type TEXT, order_number INT, status TEXT, published_at TIMESTAMPTZ, created_by UUID, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, unit_id UUID
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT l.id, l.title, l.description, l.lesson_type::TEXT, l.order_number, l.status, l.published_at, l.created_by, l.created_at, l.updated_at, l.unit_id
  FROM public.teacher_study_annotations t
  JOIN public.lessons l ON l.id = t.lesson_id
  JOIN public.units u ON u.id = l.unit_id
  JOIN public.groups g ON g.subject_id = u.subject_id
  JOIN public.enrollments e ON e.group_id = g.id
  JOIN public.group_teachers gt ON gt.group_id = g.id AND gt.teacher_id = t.teacher_id
  WHERE e.student_id = public.current_student_id() AND e.status = 'active' AND gt.is_active = true;
END;
$$;
