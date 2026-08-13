-- Make teacher lesson boards visible to students through the exact group context.
-- Student notes remain private; this only exposes the teacher layer for lessons
-- that belong to a group where the student has an active enrollment.

CREATE OR REPLACE FUNCTION public.student_can_access_group_lesson(
  p_student_id UUID,
  p_group_id UUID,
  p_lesson_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.students st
    JOIN public.enrollments e
      ON e.student_id = st.id
     AND e.group_id = p_group_id
     AND e.status = 'active'
    JOIN public.groups g ON g.id = e.group_id
    JOIN public.lessons l ON l.id = p_lesson_id
    JOIN public.units u ON u.id = l.unit_id
    LEFT JOIN public.semesters sem ON sem.id = u.semester_id
    WHERE (st.id = p_student_id OR st.profile_id = p_student_id)
      AND (
        g.subject_id = sem.subject_id
        OR EXISTS (
          SELECT 1
          FROM public.semesters sem2
          JOIN public.units u2 ON u2.semester_id = sem2.id
          WHERE u2.id = l.unit_id
            AND sem2.subject_id = g.subject_id
        )
      )
      AND (
        public.current_user_role() IN ('admin', 'staff', 'super_admin')
        OR st.id = public.current_student_id()
        OR st.profile_id = auth.uid()
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.get_group_teacher_study_annotations(
  p_lesson_id UUID,
  p_student_id UUID,
  p_group_id UUID
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

  IF NOT public.student_can_access_group_lesson(v_student_id, p_group_id, p_lesson_id) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT tsa.*
  FROM public.teacher_study_annotations tsa
  WHERE tsa.lesson_id = p_lesson_id
    AND tsa.page_number = 1
    AND tsa.annotation_type = 'freehand'::public.study_annotation_type
    AND (
      EXISTS (
        SELECT 1
        FROM public.group_teachers gt
        WHERE gt.group_id = p_group_id
          AND gt.teacher_id = tsa.teacher_id
          AND COALESCE(gt.is_active, true) = true
          AND gt.effective_from <= CURRENT_DATE
          AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
      )
      OR EXISTS (
        SELECT 1
        FROM public.lessons l
        JOIN public.units u ON u.id = l.unit_id
        LEFT JOIN public.semesters sem ON sem.id = u.semester_id
        JOIN public.groups g ON g.id = p_group_id
        WHERE l.id = p_lesson_id
          AND sem.subject_id = g.subject_id
      )
    )
  ORDER BY tsa.updated_at ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_group_teacher_study_pdf_drawings(
  p_lesson_id UUID,
  p_student_id UUID,
  p_group_id UUID
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

  IF NOT public.student_can_access_group_lesson(v_student_id, p_group_id, p_lesson_id) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT tsd.*
  FROM public.teacher_study_pdf_drawings tsd
  WHERE tsd.lesson_id = p_lesson_id
    AND tsd.page_number = 1
    AND (
      EXISTS (
        SELECT 1
        FROM public.group_teachers gt
        WHERE gt.group_id = p_group_id
          AND gt.teacher_id = tsd.teacher_id
          AND COALESCE(gt.is_active, true) = true
          AND gt.effective_from <= CURRENT_DATE
          AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
      )
      OR EXISTS (
        SELECT 1
        FROM public.lessons l
        JOIN public.units u ON u.id = l.unit_id
        LEFT JOIN public.semesters sem ON sem.id = u.semester_id
        JOIN public.groups g ON g.id = p_group_id
        WHERE l.id = p_lesson_id
          AND sem.subject_id = g.subject_id
      )
    )
  ORDER BY tsd.updated_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.student_can_access_group_lesson(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_group_teacher_study_annotations(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_group_teacher_study_pdf_drawings(UUID, UUID, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
