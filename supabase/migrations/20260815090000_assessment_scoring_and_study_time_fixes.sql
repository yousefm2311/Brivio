-- Fix assessment scoring drift and expose tracked study time to student/parent feeds.

CREATE OR REPLACE FUNCTION public.save_exam_answer(
  p_attempt_id UUID,
  p_question_id UUID,
  p_selected_option_id UUID DEFAULT NULL,
  p_text_answer TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_attempt RECORD;
  v_student_id UUID := public.current_student_id();
BEGIN
  SELECT * INTO target_attempt
  FROM public.exam_attempts
  WHERE id = p_attempt_id;

  IF target_attempt.id IS NULL THEN
    RAISE EXCEPTION 'Exam attempt not found' USING ERRCODE = '44000';
  END IF;

  IF v_student_id IS NULL OR target_attempt.student_id <> v_student_id THEN
    RAISE EXCEPTION 'Unauthorized exam attempt' USING ERRCODE = '42501';
  END IF;

  IF target_attempt.status <> 'in_progress' OR NOW() > target_attempt.expires_at THEN
    UPDATE public.exam_attempts
    SET status = CASE WHEN status = 'in_progress' THEN 'expired' ELSE status END,
        updated_at = NOW()
    WHERE id = p_attempt_id;
    RAISE EXCEPTION 'Exam attempt expired or already finalized' USING ERRCODE = '44000';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.exam_questions
    WHERE exam_id = target_attempt.exam_id
      AND question_id = p_question_id
  ) THEN
    RAISE EXCEPTION 'Question is not part of this exam' USING ERRCODE = '22023';
  END IF;

  IF p_selected_option_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.question_options
    WHERE id = p_selected_option_id
      AND question_id = p_question_id
  ) THEN
    RAISE EXCEPTION 'Selected option does not belong to this question' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.exam_answers (
    attempt_id, question_id, selected_option_id, text_answer, updated_at
  )
  VALUES (
    p_attempt_id,
    p_question_id,
    p_selected_option_id,
    NULLIF(trim(COALESCE(p_text_answer, '')), ''),
    NOW()
  )
  ON CONFLICT (attempt_id, question_id) DO UPDATE SET
    selected_option_id = EXCLUDED.selected_option_id,
    text_answer = EXCLUDED.text_answer,
    updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'attempt_id', p_attempt_id, 'question_id', p_question_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_exam_attempt(p_attempt_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_attempt RECORD;
  v_student_id UUID := public.current_student_id();
  calculated_score NUMERIC(8,2) := 0.00;
  total_max NUMERIC(8,2) := 0.00;
  manual_question_count INT := 0;
  ans RECORD;
  awarded NUMERIC(8,2);
  final_status TEXT;
BEGIN
  SELECT * INTO target_attempt
  FROM public.exam_attempts
  WHERE id = p_attempt_id;

  IF target_attempt.id IS NULL THEN
    RAISE EXCEPTION 'Exam attempt not found' USING ERRCODE = '44000';
  END IF;

  IF v_student_id IS NULL OR target_attempt.student_id <> v_student_id THEN
    RAISE EXCEPTION 'Unauthorized exam attempt' USING ERRCODE = '42501';
  END IF;

  IF target_attempt.status IN ('submitted', 'graded') THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_submitted', true,
      'score', target_attempt.score,
      'max_score', target_attempt.max_score,
      'status', target_attempt.status
    );
  END IF;

  IF target_attempt.status <> 'in_progress' OR NOW() > target_attempt.expires_at THEN
    UPDATE public.exam_attempts
    SET status = 'expired',
        updated_at = NOW()
    WHERE id = p_attempt_id;
    RAISE EXCEPTION 'Exam time is over' USING ERRCODE = '44000';
  END IF;

  SELECT COALESCE(SUM(COALESCE(eq.points, q.default_points, 1.00)), 0.00)
  INTO total_max
  FROM public.exam_questions eq
  JOIN public.questions q ON q.id = eq.question_id
  WHERE eq.exam_id = target_attempt.exam_id;

  SELECT COUNT(*)::INT
  INTO manual_question_count
  FROM public.exam_questions eq
  JOIN public.questions q ON q.id = eq.question_id
  WHERE eq.exam_id = target_attempt.exam_id
    AND q.question_type IN ('short_answer', 'long_answer');

  FOR ans IN
    SELECT
      ea.id,
      ea.question_id,
      ea.selected_option_id,
      COALESCE(eq.points, q.default_points, 1.00) AS question_points,
      qo.is_correct AS option_is_correct,
      qo.question_id AS option_question_id
    FROM public.exam_answers ea
    JOIN public.exam_questions eq
      ON eq.exam_id = target_attempt.exam_id
     AND eq.question_id = ea.question_id
    JOIN public.questions q ON q.id = ea.question_id
    LEFT JOIN public.question_options qo ON qo.id = ea.selected_option_id
    WHERE ea.attempt_id = p_attempt_id
  LOOP
    awarded := 0.00;
    IF ans.selected_option_id IS NOT NULL
       AND ans.option_question_id = ans.question_id
       AND ans.option_is_correct = true THEN
      awarded := COALESCE(ans.question_points, 1.00);
    END IF;

    calculated_score := calculated_score + awarded;

    UPDATE public.exam_answers
    SET is_correct = CASE
          WHEN ans.selected_option_id IS NULL THEN NULL
          ELSE awarded > 0
        END,
        points_awarded = awarded,
        updated_at = NOW()
    WHERE id = ans.id;
  END LOOP;

  final_status := CASE WHEN manual_question_count > 0 THEN 'submitted' ELSE 'graded' END;

  UPDATE public.exam_attempts
  SET status = final_status,
      submitted_at = NOW(),
      score = calculated_score,
      max_score = total_max,
      updated_at = NOW()
  WHERE id = p_attempt_id;

  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', p_attempt_id,
    'status', final_status,
    'score', calculated_score,
    'max_score', total_max
  );
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
  v_score NUMERIC(8,2) := 0.00;
  v_max_score NUMERIC(8,2) := 0.00;
  ans RECORD;
  q_points NUMERIC(8,2);
  q_id UUID;
  o_id UUID;
  opt_correct BOOLEAN;
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
    SELECT 1
    FROM public.enrollments
    WHERE student_id = v_student_id
      AND group_id = target_homework.group_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Student is not enrolled in this homework group' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(SUM(COALESCE(hq.points, q.default_points, 1.00)), target_homework.max_score, 0.00)
  INTO v_max_score
  FROM public.homework_questions hq
  JOIN public.questions q ON q.id = hq.question_id
  WHERE hq.homework_id = p_homework_id;

  INSERT INTO public.homework_submissions (homework_id, student_id, status, submitted_at, updated_at)
  VALUES (p_homework_id, v_student_id, 'submitted', NOW(), NOW())
  ON CONFLICT (homework_id, student_id) DO UPDATE
  SET status = 'submitted', submitted_at = NOW(), updated_at = NOW()
  RETURNING id INTO v_submission_id;

  DELETE FROM public.homework_answers WHERE submission_id = v_submission_id;

  FOR ans IN SELECT * FROM jsonb_each_text(COALESCE(p_answers, '{}'::JSONB)) LOOP
    q_id := ans.key::UUID;
    o_id := ans.value::UUID;

    SELECT COALESCE(hq.points, q.default_points, 1.00)
    INTO q_points
    FROM public.homework_questions hq
    JOIN public.questions q ON q.id = hq.question_id
    WHERE hq.homework_id = p_homework_id
      AND hq.question_id = q_id;

    IF q_points IS NULL THEN
      RAISE EXCEPTION 'Question is not part of this homework' USING ERRCODE = '22023';
    END IF;

    SELECT qo.is_correct
    INTO opt_correct
    FROM public.question_options qo
    WHERE qo.id = o_id
      AND qo.question_id = q_id;

    IF opt_correct IS NULL THEN
      RAISE EXCEPTION 'Selected option does not belong to this question' USING ERRCODE = '22023';
    END IF;

    IF opt_correct = true THEN
      v_score := v_score + COALESCE(q_points, 1.00);
    END IF;

    INSERT INTO public.homework_answers (
      submission_id,
      question_id,
      selected_option_id,
      is_correct,
      points_awarded
    )
    VALUES (
      v_submission_id,
      q_id,
      o_id,
      opt_correct,
      CASE WHEN opt_correct THEN COALESCE(q_points, 1.00) ELSE 0.00 END
    );
  END LOOP;

  UPDATE public.homework_submissions
  SET score = v_score,
      status = 'graded',
      updated_at = NOW()
  WHERE id = v_submission_id;

  RETURN jsonb_build_object(
    'success', true,
    'submission_id', v_submission_id,
    'score', v_score,
    'max_score', v_max_score
  );
END;
$$;

DROP FUNCTION IF EXISTS public.get_current_student_lessons();
CREATE OR REPLACE FUNCTION public.get_current_student_lessons()
RETURNS TABLE (
  lesson_id UUID,
  lesson_title TEXT,
  group_id UUID,
  subject_name TEXT,
  unit_name TEXT,
  progress_percentage NUMERIC,
  estimated_minutes INT,
  last_page INT,
  total_pages INT,
  time_spent_seconds INT,
  has_pdf BOOLEAN,
  has_code_playground BOOLEAN,
  pdf_bucket TEXT,
  pdf_object_path TEXT
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
  SELECT DISTINCT ON (g.id, l.id)
    l.id AS lesson_id,
    COALESCE(l.title, 'Untitled lesson')::TEXT AS lesson_title,
    g.id AS group_id,
    COALESCE(s.name, 'Assigned subject')::TEXT AS subject_name,
    COALESCE(u.name, 'Unit')::TEXT AS unit_name,
    COALESCE(lp.progress_percentage, 0)::NUMERIC AS progress_percentage,
    COALESCE(l.estimated_duration_minutes, 0)::INT AS estimated_minutes,
    GREATEST(1, COALESCE(CASE WHEN COALESCE(lp.last_position, '') ~ '^[0-9]+$' THEN lp.last_position::INT ELSE NULL END, 1))::INT AS last_page,
    GREATEST(1, COALESCE(NULLIF((lr.metadata->>'page_count'), '')::INT, 1))::INT AS total_pages,
    COALESCE(lp.time_spent_seconds, 0)::INT AS time_spent_seconds,
    (lr.id IS NOT NULL)::BOOLEAN AS has_pdf,
    (l.lesson_type::TEXT = 'programming')::BOOLEAN AS has_code_playground,
    lr.bucket::TEXT AS pdf_bucket,
    lr.object_path::TEXT AS pdf_object_path
  FROM public.enrollments e
  JOIN public.groups g ON g.id = e.group_id
  JOIN public.semesters sem ON sem.subject_id = g.subject_id
  JOIN public.units u ON u.semester_id = sem.id
  JOIN public.lessons l ON l.unit_id = u.id
  LEFT JOIN public.subjects s ON s.id = g.subject_id
  LEFT JOIN public.lesson_progress lp ON lp.lesson_id = l.id AND lp.student_id = v_student_id
  LEFT JOIN public.lesson_resources lr ON lr.lesson_id = l.id AND lr.resource_type = 'pdf'
  WHERE e.student_id = v_student_id
    AND public.enrollment_has_learning_access(e.id)
    AND g.status = 'active'
    AND u.status = 'active'
    AND l.status = 'published'
  ORDER BY g.id, l.id, sem.order_number, u.order_number, l.order_number, lr.order_number;
END;
$$;

DROP FUNCTION IF EXISTS public.get_accessible_student_lessons(UUID);
CREATE OR REPLACE FUNCTION public.get_accessible_student_lessons(p_student_id UUID)
RETURNS TABLE (
  lesson_id UUID,
  lesson_title TEXT,
  group_id UUID,
  subject_name TEXT,
  unit_name TEXT,
  progress_percentage NUMERIC,
  estimated_minutes INT,
  last_page INT,
  total_pages INT,
  time_spent_seconds INT,
  has_pdf BOOLEAN,
  has_code_playground BOOLEAN,
  pdf_bucket TEXT,
  pdf_object_path TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_student_id IS NULL THEN
    RAISE EXCEPTION 'Student id is required' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    p_student_id = public.current_student_id()
    OR public.current_parent_has_student(p_student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view student lessons' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (g.id, l.id)
    l.id AS lesson_id,
    COALESCE(l.title, 'Untitled lesson')::TEXT AS lesson_title,
    g.id AS group_id,
    COALESCE(s.name, 'Assigned subject')::TEXT AS subject_name,
    COALESCE(u.name, 'Unit')::TEXT AS unit_name,
    COALESCE(lp.progress_percentage, 0)::NUMERIC AS progress_percentage,
    COALESCE(l.estimated_duration_minutes, 0)::INT AS estimated_minutes,
    GREATEST(1, COALESCE(CASE WHEN COALESCE(lp.last_position, '') ~ '^[0-9]+$' THEN lp.last_position::INT ELSE NULL END, 1))::INT AS last_page,
    GREATEST(1, COALESCE(NULLIF((lr.metadata->>'page_count'), '')::INT, 1))::INT AS total_pages,
    COALESCE(lp.time_spent_seconds, 0)::INT AS time_spent_seconds,
    (lr.id IS NOT NULL)::BOOLEAN AS has_pdf,
    (l.lesson_type::TEXT = 'programming')::BOOLEAN AS has_code_playground,
    lr.bucket::TEXT AS pdf_bucket,
    lr.object_path::TEXT AS pdf_object_path
  FROM public.enrollments e
  JOIN public.groups g ON g.id = e.group_id
  JOIN public.semesters sem ON sem.subject_id = g.subject_id
  JOIN public.units u ON u.semester_id = sem.id
  JOIN public.lessons l ON l.unit_id = u.id
  LEFT JOIN public.subjects s ON s.id = g.subject_id
  LEFT JOIN public.lesson_progress lp ON lp.lesson_id = l.id AND lp.student_id = p_student_id
  LEFT JOIN public.lesson_resources lr ON lr.lesson_id = l.id AND lr.resource_type = 'pdf'
  WHERE e.student_id = p_student_id
    AND public.enrollment_has_learning_access(e.id)
    AND g.status = 'active'
    AND u.status = 'active'
    AND l.status = 'published'
  ORDER BY g.id, l.id, sem.order_number, u.order_number, l.order_number, lr.order_number;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.save_exam_answer(UUID, UUID, UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_exam_attempt(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_homework_mcq(UUID, JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_current_student_lessons() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_accessible_student_lessons(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.save_exam_answer(UUID, UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_exam_attempt(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_homework_mcq(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_student_lessons() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_accessible_student_lessons(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
