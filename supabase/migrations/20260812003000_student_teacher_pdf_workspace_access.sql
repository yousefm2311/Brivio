-- Keep teacher PDF board layers visible to students for the same published lesson.
-- This supports both normalized curriculum links (semesters.subject_id) and the
-- runtime compatibility column (units.subject_id).

CREATE OR REPLACE FUNCTION public.get_student_teacher_study_annotations(
  p_lesson_id UUID,
  p_student_id UUID
)
RETURNS SETOF public.teacher_study_annotations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
  JOIN public.lessons l ON l.id = tsa.lesson_id
  JOIN public.units u ON u.id = l.unit_id
  LEFT JOIN public.semesters sem ON sem.id = u.semester_id
  JOIN public.group_teachers gt ON gt.teacher_id = tsa.teacher_id
  JOIN public.enrollments e ON e.group_id = gt.group_id
  JOIN public.groups g ON g.id = e.group_id
  WHERE tsa.lesson_id = p_lesson_id
    AND e.student_id = v_student_id
    AND e.status = 'active'
    AND COALESCE(gt.is_active, true) = true
    AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
    AND (
      g.subject_id = u.subject_id
      OR g.subject_id = sem.subject_id
      OR l.created_by = (
        SELECT t.profile_id
        FROM public.teachers t
        WHERE t.id = tsa.teacher_id
        LIMIT 1
      )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_student_teacher_study_pdf_drawings(
  p_lesson_id UUID,
  p_student_id UUID
)
RETURNS SETOF public.teacher_study_pdf_drawings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
  JOIN public.lessons l ON l.id = tsd.lesson_id
  JOIN public.units u ON u.id = l.unit_id
  LEFT JOIN public.semesters sem ON sem.id = u.semester_id
  JOIN public.group_teachers gt ON gt.teacher_id = tsd.teacher_id
  JOIN public.enrollments e ON e.group_id = gt.group_id
  JOIN public.groups g ON g.id = e.group_id
  WHERE tsd.lesson_id = p_lesson_id
    AND e.student_id = v_student_id
    AND e.status = 'active'
    AND COALESCE(gt.is_active, true) = true
    AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
    AND (
      g.subject_id = u.subject_id
      OR g.subject_id = sem.subject_id
      OR l.created_by = (
        SELECT t.profile_id
        FROM public.teachers t
        WHERE t.id = tsd.teacher_id
        LIMIT 1
      )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_teacher_study_annotations(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_student_teacher_study_pdf_drawings(UUID, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
