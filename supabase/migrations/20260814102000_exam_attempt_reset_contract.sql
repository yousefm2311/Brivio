-- Exam attempts contract:
-- one base attempt per student, plus one extra attempt for each approved reset.

UPDATE public.exams
SET max_attempts = 1
WHERE COALESCE(max_attempts, 1) <> 1;

ALTER TABLE public.exams
ALTER COLUMN max_attempts SET DEFAULT 1;

CREATE TABLE IF NOT EXISTS public.exam_reset_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_pending_reset_request UNIQUE (exam_id, student_id, status)
    DEFERRABLE INITIALLY DEFERRED
);

ALTER TABLE public.exam_reset_requests ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.exam_reset_requests
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.reset_student_exam_attempt(
  p_exam_id UUID,
  p_student_id UUID
)
RETURNS BOOLEAN
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
    OR public.current_teacher_assigned_to_group(v_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to approve exam reset' USING ERRCODE = '42501';
  END IF;

  UPDATE public.exam_reset_requests
  SET status = 'approved',
      approved_at = NOW(),
      approved_by = auth.uid(),
      updated_at = NOW()
  WHERE exam_id = p_exam_id
    AND student_id = p_student_id
    AND status = 'pending';

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.start_exam(p_exam_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s_id UUID;
  target_exam RECORD;
  current_attempt_count INT;
  approved_reset_count INT;
  allowed_attempts INT;
  new_attempt_id UUID;
  calc_expires_at TIMESTAMPTZ;
  total_max NUMERIC(6,2);
BEGIN
  SELECT id INTO s_id
  FROM public.students
  WHERE profile_id = auth.uid() AND status = 'active';

  IF s_id IS NULL THEN
    RAISE EXCEPTION 'Only active enrolled students can start an exam' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO target_exam
  FROM public.exams
  WHERE id = p_exam_id AND status = 'published';

  IF target_exam.id IS NULL THEN
    RAISE EXCEPTION 'Exam not available or not published' USING ERRCODE = '44000';
  END IF;

  IF target_exam.available_from IS NOT NULL AND NOW() < target_exam.available_from THEN
    RAISE EXCEPTION 'Exam has not opened yet' USING ERRCODE = '44000';
  END IF;

  IF target_exam.available_until IS NOT NULL AND NOW() > target_exam.available_until THEN
    RAISE EXCEPTION 'Exam window has ended' USING ERRCODE = '44000';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.enrollments e
    WHERE e.student_id = s_id
      AND e.group_id = target_exam.group_id
      AND e.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Student is not enrolled in this exam group' USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*)::INT INTO current_attempt_count
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id AND student_id = s_id;

  SELECT COUNT(*)::INT INTO approved_reset_count
  FROM public.exam_reset_requests
  WHERE exam_id = p_exam_id
    AND student_id = s_id
    AND status = 'approved';

  allowed_attempts := 1 + approved_reset_count;

  IF current_attempt_count >= allowed_attempts THEN
    RAISE EXCEPTION 'Maximum exam attempts reached. Request a reset from your teacher.' USING ERRCODE = '44000';
  END IF;

  SELECT COALESCE(SUM(points), 0.00) INTO total_max
  FROM public.exam_questions
  WHERE exam_id = p_exam_id;

  calc_expires_at := NOW() + (target_exam.duration_minutes || ' minutes')::INTERVAL;
  new_attempt_id := gen_random_uuid();

  INSERT INTO public.exam_attempts (
    id,
    exam_id,
    student_id,
    attempt_number,
    status,
    started_at,
    expires_at,
    max_score
  )
  VALUES (
    new_attempt_id,
    p_exam_id,
    s_id,
    current_attempt_count + 1,
    'in_progress',
    NOW(),
    calc_expires_at,
    total_max
  );

  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', new_attempt_id,
    'attempt_number', current_attempt_count + 1,
    'expires_at', calc_expires_at,
    'max_score', total_max
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.reset_student_exam_attempt(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_exam(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
