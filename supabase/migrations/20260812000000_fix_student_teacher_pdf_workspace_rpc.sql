-- Fix student access to teacher PDF workspace boards/annotations.
-- The app passes students.id, while the original RPC treated p_student_id as profiles.id.

CREATE OR REPLACE FUNCTION public.get_student_teacher_study_annotations(
  p_lesson_id UUID,
  p_student_id UUID
)
RETURNS SETOF public.teacher_study_annotations
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID;
BEGIN
  SELECT s.id
    INTO v_student_id
  FROM public.students s
  WHERE s.id = p_student_id OR s.profile_id = p_student_id
  LIMIT 1;

  IF v_student_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT DISTINCT tsa.*
  FROM public.teacher_study_annotations tsa
  JOIN public.group_teachers gt ON gt.teacher_id = tsa.teacher_id
  JOIN public.enrollments e ON e.group_id = gt.group_id
  WHERE tsa.lesson_id = p_lesson_id
    AND e.student_id = v_student_id
    AND e.status = 'active'
    AND gt.is_active = true
    AND (gt.effective_end_date IS NULL OR gt.effective_end_date > NOW());
END;
$$;

CREATE OR REPLACE FUNCTION public.get_student_teacher_study_pdf_drawings(
  p_lesson_id UUID,
  p_student_id UUID
)
RETURNS SETOF public.teacher_study_pdf_drawings
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID;
BEGIN
  SELECT s.id
    INTO v_student_id
  FROM public.students s
  WHERE s.id = p_student_id OR s.profile_id = p_student_id
  LIMIT 1;

  IF v_student_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT DISTINCT tsd.*
  FROM public.teacher_study_pdf_drawings tsd
  JOIN public.group_teachers gt ON gt.teacher_id = tsd.teacher_id
  JOIN public.enrollments e ON e.group_id = gt.group_id
  WHERE tsd.lesson_id = p_lesson_id
    AND e.student_id = v_student_id
    AND e.status = 'active'
    AND gt.is_active = true
    AND (gt.effective_end_date IS NULL OR gt.effective_end_date > NOW());
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_teacher_study_annotations(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_student_teacher_study_pdf_drawings(UUID, UUID) TO authenticated;
