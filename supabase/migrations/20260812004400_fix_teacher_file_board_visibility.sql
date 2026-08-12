-- Fix teacher lesson file board visibility for students.
-- The teacher side board is stored in teacher_study_annotations.geometry,
-- while PDF freehand layers are stored in teacher_study_pdf_drawings.strokes.
-- These RPCs keep both paths readable by enrolled students for the same lesson.

DELETE FROM public.teacher_study_annotations a
USING public.teacher_study_annotations b
WHERE a.id > b.id
  AND a.teacher_id = b.teacher_id
  AND a.lesson_id = b.lesson_id
  AND a.page_number = b.page_number
  AND a.annotation_type = b.annotation_type;

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_teacher_study_board_annotation
ON public.teacher_study_annotations(teacher_id, lesson_id, page_number, annotation_type);

CREATE OR REPLACE FUNCTION public.save_teacher_study_board(
  p_teacher_id UUID,
  p_lesson_id UUID,
  p_board_data TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID;
BEGIN
  SELECT t.id
    INTO v_teacher_id
  FROM public.teachers t
  WHERE t.id = p_teacher_id OR t.profile_id = p_teacher_id
  LIMIT 1;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Teacher profile is not linked to a teacher record';
  END IF;

  IF v_teacher_id <> public.current_teacher_id()
     AND public.current_user_role() NOT IN ('admin', 'staff', 'super_admin') THEN
    RAISE EXCEPTION 'Not allowed to save this teacher board';
  END IF;

  INSERT INTO public.teacher_study_annotations (
    teacher_id,
    lesson_id,
    page_number,
    annotation_type,
    color,
    geometry,
    content,
    created_at,
    updated_at
  )
  VALUES (
    v_teacher_id,
    p_lesson_id,
    1,
    'freehand'::public.study_annotation_type,
    '#1E40AF',
    jsonb_build_object('board_data', COALESCE(p_board_data, '')),
    'Smart notebook board',
    NOW(),
    NOW()
  )
  ON CONFLICT (teacher_id, lesson_id, page_number, annotation_type)
  DO UPDATE SET
    color = EXCLUDED.color,
    geometry = EXCLUDED.geometry,
    content = EXCLUDED.content,
    updated_at = NOW();
END;
$$;

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
  LEFT JOIN public.units u ON u.id = l.unit_id
  LEFT JOIN public.semesters sem ON sem.id = u.semester_id
  WHERE tsa.lesson_id = p_lesson_id
    AND (
      public.current_user_role() IN ('admin', 'staff', 'super_admin')
      OR v_student_id = public.current_student_id()
      OR EXISTS (
        SELECT 1
        FROM public.students s
        WHERE s.id = v_student_id
          AND s.profile_id = auth.uid()
      )
    )
    AND EXISTS (
      SELECT 1
      FROM public.enrollments e
      JOIN public.groups g ON g.id = e.group_id
      LEFT JOIN public.group_teachers gt
        ON gt.group_id = g.id
       AND gt.teacher_id = tsa.teacher_id
       AND COALESCE(gt.is_active, true) = true
       AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
      LEFT JOIN public.teachers t ON t.id = tsa.teacher_id
      WHERE e.student_id = v_student_id
        AND e.status = 'active'
        AND (
          g.subject_id = u.subject_id
          OR g.subject_id = sem.subject_id
          OR gt.teacher_id IS NOT NULL
          OR l.created_by = t.profile_id
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
  LEFT JOIN public.units u ON u.id = l.unit_id
  LEFT JOIN public.semesters sem ON sem.id = u.semester_id
  WHERE tsd.lesson_id = p_lesson_id
    AND (
      public.current_user_role() IN ('admin', 'staff', 'super_admin')
      OR v_student_id = public.current_student_id()
      OR EXISTS (
        SELECT 1
        FROM public.students s
        WHERE s.id = v_student_id
          AND s.profile_id = auth.uid()
      )
    )
    AND EXISTS (
      SELECT 1
      FROM public.enrollments e
      JOIN public.groups g ON g.id = e.group_id
      LEFT JOIN public.group_teachers gt
        ON gt.group_id = g.id
       AND gt.teacher_id = tsd.teacher_id
       AND COALESCE(gt.is_active, true) = true
       AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
      LEFT JOIN public.teachers t ON t.id = tsd.teacher_id
      WHERE e.student_id = v_student_id
        AND e.status = 'active'
        AND (
          g.subject_id = u.subject_id
          OR g.subject_id = sem.subject_id
          OR gt.teacher_id IS NOT NULL
          OR l.created_by = t.profile_id
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_teacher_study_board(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_student_teacher_study_annotations(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_student_teacher_study_pdf_drawings(UUID, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
