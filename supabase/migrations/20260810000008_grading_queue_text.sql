-- Update the grading queue function to include submission_text and attachment_url

DROP FUNCTION IF EXISTS public.get_teacher_grading_queue(UUID);

CREATE OR REPLACE FUNCTION public.get_teacher_grading_queue(p_teacher_id UUID)
RETURNS TABLE (
  id UUID,
  homework_id UUID,
  student_id UUID,
  status TEXT,
  score NUMERIC,
  submitted_at TIMESTAMPTZ,
  max_score NUMERIC,
  homework_title TEXT,
  group_id UUID,
  student_full_name TEXT,
  student_email TEXT,
  submission_text TEXT,
  attachment_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('homework.grade')
    OR p_teacher_id = public.current_teacher_id()
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view grading queue' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    hs.id,
    hs.homework_id,
    hs.student_id,
    COALESCE(hs.status, 'submitted')::TEXT AS status,
    hs.score,
    hs.submitted_at,
    h.max_score,
    COALESCE(h.title, 'Homework')::TEXT AS homework_title,
    h.group_id,
    COALESCE(p.full_name, 'Student')::TEXT AS student_full_name,
    COALESCE(p.email, '')::TEXT AS student_email,
    hs.submission_text,
    hs.attachment_url
  FROM public.homework_submissions hs
  JOIN public.homework h ON h.id = hs.homework_id
  JOIN public.students s ON s.id = hs.student_id
  LEFT JOIN public.profiles p ON p.id = s.profile_id
  WHERE h.group_id IN (
    SELECT gt.group_id
    FROM public.group_teachers gt
    WHERE gt.teacher_id = p_teacher_id
      AND gt.effective_from <= CURRENT_DATE
      AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
  )
  ORDER BY hs.submitted_at DESC NULLS LAST, hs.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_teacher_grading_queue(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_grading_queue(UUID) TO authenticated;
