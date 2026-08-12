-- Make the teacher attempts RPC resilient and re-install it on databases that
-- already applied the earlier get_teacher_exam_attempts migration.

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
  v_exam_exists BOOLEAN := false;
BEGIN
  SELECT true, ex.group_id
  INTO v_exam_exists, v_group_id
  FROM public.exams ex
  WHERE ex.id = p_exam_id;

  IF NOT COALESCE(v_exam_exists, false) THEN
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
    COALESCE(NULLIF(trim(p.full_name), ''), s.student_code, 'Unknown Student')::TEXT AS student_name,
    s.student_code::TEXT,
    att.attempt_number,
    att.status::TEXT,
    att.score,
    att.max_score,
    att.started_at,
    att.submitted_at,
    att.teacher_feedback::TEXT
  FROM public.exam_attempts att
  LEFT JOIN public.students s ON s.id = att.student_id
  LEFT JOIN public.profiles p ON p.id = s.profile_id
  WHERE att.exam_id = p_exam_id
  ORDER BY COALESCE(NULLIF(trim(p.full_name), ''), s.student_code, 'Unknown Student'), att.attempt_number;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_exam_attempts(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
