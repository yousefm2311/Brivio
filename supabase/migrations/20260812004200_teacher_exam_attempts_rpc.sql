-- Return exam attempts with resolved student profile data for teacher review screens.

CREATE OR REPLACE FUNCTION public.get_teacher_exam_attempts(p_exam_id UUID)
RETURNS TABLE (
  id UUID,
  exam_id UUID,
  student_id UUID,
  student_name TEXT,
  student_code TEXT,
  attempt_number INT,
  status TEXT,
  score NUMERIC,
  max_score NUMERIC,
  started_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ,
  teacher_feedback TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id UUID;
BEGIN
  SELECT group_id INTO v_group_id
  FROM public.exams
  WHERE id = p_exam_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Exam not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('exams.grade')
    OR public.current_teacher_assigned_to_group(v_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view exam attempts' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    att.id,
    att.exam_id,
    att.student_id,
    COALESCE(NULLIF(trim(p.full_name), ''), s.student_code, 'Unknown Student') AS student_name,
    s.student_code,
    att.attempt_number,
    att.status,
    att.score,
    att.max_score,
    att.started_at,
    att.submitted_at,
    att.teacher_feedback
  FROM public.exam_attempts att
  JOIN public.students s ON s.id = att.student_id
  JOIN public.profiles p ON p.id = s.profile_id
  WHERE att.exam_id = p_exam_id
  ORDER BY p.full_name, s.student_code, att.attempt_number;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_exam_attempts(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
