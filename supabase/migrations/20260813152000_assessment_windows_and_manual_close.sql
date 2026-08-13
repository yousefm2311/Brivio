-- Adds assessment availability windows and server-side locking for exams/homework.

ALTER TABLE public.homework
  ADD COLUMN IF NOT EXISTS available_from TIMESTAMPTZ;

ALTER TABLE public.exams
  ADD COLUMN IF NOT EXISTS available_from TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS available_until TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_homework_status_window
ON public.homework(group_id, status, available_from, due_at);

CREATE INDEX IF NOT EXISTS idx_exams_status_window
ON public.exams(group_id, status, available_from, available_until);

DROP FUNCTION IF EXISTS public.get_student_homework_feed();
CREATE OR REPLACE FUNCTION public.get_student_homework_feed()
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  subject_id UUID,
  group_id UUID,
  available_from TIMESTAMPTZ,
  due_at TIMESTAMPTZ,
  max_score NUMERIC,
  status TEXT,
  group_name TEXT,
  submission_status TEXT,
  submission_score NUMERIC,
  teacher_feedback TEXT,
  submitted_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    h.id,
    h.title,
    h.description,
    h.subject_id,
    h.group_id,
    h.available_from,
    h.due_at,
    h.max_score,
    CASE
      WHEN h.status = 'published' AND NOW() > h.due_at THEN 'closed'
      ELSE h.status
    END::TEXT AS status,
    COALESCE(g.name, 'Group')::TEXT AS group_name,
    hs.status AS submission_status,
    hs.score AS submission_score,
    hs.teacher_feedback,
    hs.submitted_at
  FROM public.homework h
  JOIN public.groups g ON g.id = h.group_id
  JOIN public.enrollments e ON e.group_id = h.group_id
  LEFT JOIN public.homework_submissions hs
    ON hs.homework_id = h.id
   AND hs.student_id = v_student_id
  WHERE e.student_id = v_student_id
    AND e.status = 'active'
    AND h.status IN ('published', 'closed')
  ORDER BY h.due_at ASC;
END;
$$;

DROP FUNCTION IF EXISTS public.get_student_exam_feed();
CREATE OR REPLACE FUNCTION public.get_student_exam_feed()
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  subject_id UUID,
  group_id UUID,
  duration_minutes INT,
  max_attempts INT,
  pass_score NUMERIC,
  status TEXT,
  result_release_policy TEXT,
  available_from TIMESTAMPTZ,
  available_until TIMESTAMPTZ,
  group_name TEXT,
  attempt_count INT,
  last_attempt_status TEXT,
  last_score NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    ex.id,
    ex.title,
    ex.description,
    ex.subject_id,
    ex.group_id,
    ex.duration_minutes,
    ex.max_attempts,
    ex.pass_score,
    CASE
      WHEN ex.status = 'published'
       AND ex.available_until IS NOT NULL
       AND NOW() > ex.available_until THEN 'closed'
      ELSE ex.status
    END::TEXT AS status,
    ex.result_release_policy,
    ex.available_from,
    ex.available_until,
    COALESCE(g.name, 'Group')::TEXT AS group_name,
    COALESCE(att_stats.attempt_count, 0)::INT AS attempt_count,
    att_stats.last_attempt_status,
    att_stats.last_score
  FROM public.exams ex
  JOIN public.groups g ON g.id = ex.group_id
  JOIN public.enrollments e ON e.group_id = ex.group_id
  LEFT JOIN LATERAL (
    SELECT
      COUNT(*)::INT AS attempt_count,
      (ARRAY_AGG(a.status ORDER BY a.created_at DESC))[1] AS last_attempt_status,
      (ARRAY_AGG(a.score ORDER BY a.created_at DESC))[1] AS last_score
    FROM public.exam_attempts a
    WHERE a.exam_id = ex.id
      AND a.student_id = v_student_id
  ) att_stats ON true
  WHERE e.student_id = v_student_id
    AND e.status = 'active'
    AND ex.status IN ('published', 'closed')
  ORDER BY ex.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.create_homework_assignment(
  TEXT, TEXT, UUID, UUID, TIMESTAMPTZ, NUMERIC, TEXT
);
DROP FUNCTION IF EXISTS public.create_homework_assignment(
  TEXT, TEXT, UUID, UUID, TIMESTAMPTZ, NUMERIC, TEXT, TIMESTAMPTZ
);
CREATE OR REPLACE FUNCTION public.create_homework_assignment(
  p_title TEXT,
  p_description TEXT,
  p_subject_id UUID,
  p_group_id UUID,
  p_due_at TIMESTAMPTZ,
  p_max_score NUMERIC,
  p_status TEXT DEFAULT 'published',
  p_available_from TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_homework_id UUID;
  v_result JSONB;
BEGIN
  IF p_due_at <= COALESCE(p_available_from, NOW()) THEN
    RAISE EXCEPTION 'Homework close time must be after open time' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('homework.create')
    OR public.current_teacher_assigned_to_group(p_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to create homework for this group' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.homework (
    title, description, subject_id, group_id, assigned_by, available_from,
    due_at, max_score, status
  ) VALUES (
    p_title, p_description, p_subject_id, p_group_id, auth.uid(),
    p_available_from, p_due_at, COALESCE(p_max_score, 100.00),
    COALESCE(p_status, 'published')
  )
  RETURNING id INTO v_homework_id;

  SELECT to_jsonb(h.*) INTO v_result
  FROM public.homework h
  WHERE h.id = v_homework_id;

  RETURN v_result;
END;
$$;

DROP FUNCTION IF EXISTS public.create_exam_assignment(TEXT, UUID, UUID, INT, NUMERIC, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.create_exam_assignment(TEXT, UUID, UUID, INT, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.create_exam_assignment(TEXT, UUID, UUID, INT, NUMERIC, TEXT, TIMESTAMPTZ, TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION public.create_exam_assignment(
  p_title TEXT,
  p_subject_id UUID,
  p_group_id UUID,
  p_duration_minutes INT,
  p_pass_score NUMERIC,
  p_status TEXT DEFAULT 'published',
  p_available_from TIMESTAMPTZ DEFAULT NULL,
  p_available_until TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exam_id UUID;
  v_result JSONB;
BEGIN
  IF p_available_until IS NOT NULL
     AND p_available_until <= COALESCE(p_available_from, NOW()) THEN
    RAISE EXCEPTION 'Exam close time must be after open time' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('exams.create')
    OR public.current_teacher_assigned_to_group(p_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to create exam for this group' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.exams (
    title, subject_id, group_id, duration_minutes, pass_score, status,
    result_release_policy, available_from, available_until, created_by
  ) VALUES (
    p_title, p_subject_id, p_group_id, COALESCE(p_duration_minutes, 60),
    COALESCE(p_pass_score, 50.00), COALESCE(p_status, 'published'),
    'immediate', p_available_from, p_available_until, auth.uid()
  )
  RETURNING id INTO v_exam_id;

  SELECT to_jsonb(e.*) INTO v_result
  FROM public.exams e
  WHERE e.id = v_exam_id;

  RETURN v_result;
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
  WHERE id = p_exam_id;

  IF target_exam.id IS NULL OR target_exam.status <> 'published' THEN
    RAISE EXCEPTION 'Exam is closed or not published' USING ERRCODE = '44000';
  END IF;

  IF target_exam.available_from IS NOT NULL AND NOW() < target_exam.available_from THEN
    RAISE EXCEPTION 'Exam has not started yet' USING ERRCODE = '44000';
  END IF;

  IF target_exam.available_until IS NOT NULL AND NOW() > target_exam.available_until THEN
    UPDATE public.exams SET status = 'closed', updated_at = NOW() WHERE id = p_exam_id;
    RAISE EXCEPTION 'Exam time is over' USING ERRCODE = '44000';
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

  SELECT COUNT(*)::int INTO current_attempt_count
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id AND student_id = s_id;

  IF current_attempt_count >= target_exam.max_attempts THEN
    RAISE EXCEPTION 'Maximum exam attempts reached' USING ERRCODE = '44000';
  END IF;

  SELECT COALESCE(SUM(points), 0.00) INTO total_max
  FROM public.exam_questions
  WHERE exam_id = p_exam_id;

  calc_expires_at := NOW() + (target_exam.duration_minutes || ' minutes')::INTERVAL;
  IF target_exam.available_until IS NOT NULL THEN
    calc_expires_at := LEAST(calc_expires_at, target_exam.available_until);
  END IF;

  new_attempt_id := gen_random_uuid();

  INSERT INTO public.exam_attempts (
    id, exam_id, student_id, attempt_number, status, started_at, expires_at, max_score
  )
  VALUES (
    new_attempt_id, p_exam_id, s_id, current_attempt_count + 1,
    'in_progress', NOW(), calc_expires_at, total_max
  );

  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', new_attempt_id,
    'attempt_number', current_attempt_count + 1,
    'started_at', NOW(),
    'expires_at', calc_expires_at,
    'max_score', total_max
  );
END;
$$;

DROP FUNCTION IF EXISTS public.submit_homework_text(UUID, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.submit_homework_text(
  p_homework_id UUID,
  p_submission_text TEXT,
  p_attachment_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
  target_homework RECORD;
  v_submission_id UUID;
  v_result JSONB;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO target_homework
  FROM public.homework
  WHERE id = p_homework_id;

  IF target_homework.id IS NULL OR target_homework.status <> 'published' THEN
    RAISE EXCEPTION 'Homework is closed or not published' USING ERRCODE = '44000';
  END IF;

  IF target_homework.available_from IS NOT NULL AND NOW() < target_homework.available_from THEN
    RAISE EXCEPTION 'Homework has not started yet' USING ERRCODE = '44000';
  END IF;

  IF NOW() > target_homework.due_at THEN
    UPDATE public.homework SET status = 'closed', updated_at = NOW() WHERE id = p_homework_id;
    RAISE EXCEPTION 'Homework time is over' USING ERRCODE = '44000';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.enrollments
    WHERE student_id = v_student_id
      AND group_id = target_homework.group_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Student is not enrolled in this homework group' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.homework_submissions (
    homework_id, student_id, status, submission_text, attachment_url, submitted_at, updated_at
  ) VALUES (
    p_homework_id, v_student_id, 'submitted',
    NULLIF(trim(COALESCE(p_submission_text, '')), ''),
    NULLIF(trim(COALESCE(p_attachment_url, '')), ''),
    NOW(), NOW()
  )
  ON CONFLICT (homework_id, student_id) DO UPDATE SET
    status = 'submitted',
    submission_text = EXCLUDED.submission_text,
    attachment_url = EXCLUDED.attachment_url,
    submitted_at = NOW(),
    updated_at = NOW()
  RETURNING id INTO v_submission_id;

  SELECT to_jsonb(s.*) INTO v_result
  FROM public.homework_submissions s
  WHERE s.id = v_submission_id;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_homework_mcq(p_homework_id UUID, p_answers JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
  target_homework RECORD;
  v_submission_id UUID;
  v_score NUMERIC(6,2) := 0.00;
  v_max_score NUMERIC(6,2);
  ans RECORD;
  opt_correct BOOLEAN;
  q_points NUMERIC(6,2);
  q_id UUID;
  o_id UUID;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile not found' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO target_homework
  FROM public.homework
  WHERE id = p_homework_id;

  IF target_homework.id IS NULL OR target_homework.status <> 'published' THEN
    RAISE EXCEPTION 'Homework is closed or not published' USING ERRCODE = '44000';
  END IF;

  IF target_homework.available_from IS NOT NULL AND NOW() < target_homework.available_from THEN
    RAISE EXCEPTION 'Homework has not started yet' USING ERRCODE = '44000';
  END IF;

  IF NOW() > target_homework.due_at THEN
    UPDATE public.homework SET status = 'closed', updated_at = NOW() WHERE id = p_homework_id;
    RAISE EXCEPTION 'Homework time is over' USING ERRCODE = '44000';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.enrollments
    WHERE student_id = v_student_id
      AND group_id = target_homework.group_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Student is not enrolled in this homework group' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.homework_submissions (homework_id, student_id, status, submitted_at, updated_at)
  VALUES (p_homework_id, v_student_id, 'submitted', NOW(), NOW())
  ON CONFLICT (homework_id, student_id) DO UPDATE
  SET status = 'submitted', submitted_at = NOW(), updated_at = NOW()
  RETURNING id INTO v_submission_id;

  DELETE FROM public.homework_answers WHERE submission_id = v_submission_id;

  FOR ans IN SELECT * FROM jsonb_each_text(p_answers) LOOP
    q_id := ans.key::UUID;
    o_id := ans.value::UUID;

    SELECT is_correct INTO opt_correct FROM public.question_options WHERE id = o_id;
    SELECT points INTO q_points
    FROM public.homework_questions
    WHERE homework_id = p_homework_id AND question_id = q_id;

    IF opt_correct = true THEN
      v_score := v_score + COALESCE(q_points, 1.00);
      INSERT INTO public.homework_answers (submission_id, question_id, selected_option_id, is_correct, points_awarded)
      VALUES (v_submission_id, q_id, o_id, true, COALESCE(q_points, 1.00));
    ELSE
      INSERT INTO public.homework_answers (submission_id, question_id, selected_option_id, is_correct, points_awarded)
      VALUES (v_submission_id, q_id, o_id, false, 0.00);
    END IF;
  END LOOP;

  SELECT max_score INTO v_max_score FROM public.homework WHERE id = p_homework_id;

  UPDATE public.homework_submissions
  SET score = v_score, status = 'graded', updated_at = NOW()
  WHERE id = v_submission_id;

  RETURN jsonb_build_object(
    'success', true,
    'submission_id', v_submission_id,
    'score', v_score,
    'max_score', v_max_score
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_homework_assignment(TEXT, TEXT, UUID, UUID, TIMESTAMPTZ, NUMERIC, TEXT, TIMESTAMPTZ) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_exam_assignment(TEXT, UUID, UUID, INT, NUMERIC, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.start_exam(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_homework_text(UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_homework_mcq(UUID, JSONB) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_homework_assignment(TEXT, TEXT, UUID, UUID, TIMESTAMPTZ, NUMERIC, TEXT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_exam_assignment(TEXT, UUID, UUID, INT, NUMERIC, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_exam(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_homework_text(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_homework_mcq(UUID, JSONB) TO authenticated;
