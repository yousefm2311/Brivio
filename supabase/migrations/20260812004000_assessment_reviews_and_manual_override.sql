-- Student/teacher assessment review and per-question manual grading support.

CREATE OR REPLACE FUNCTION public.get_my_homework_review(p_homework_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
  v_submission RECORD;
  v_answers JSONB;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile not found' USING ERRCODE = '42501';
  END IF;

  SELECT hs.*, h.title, h.max_score
  INTO v_submission
  FROM public.homework_submissions hs
  JOIN public.homework h ON h.id = hs.homework_id
  WHERE hs.homework_id = p_homework_id
    AND hs.student_id = v_student_id
  LIMIT 1;

  IF v_submission.id IS NULL THEN
    RETURN jsonb_build_object('released', false, 'message', 'No submission found');
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'answer_id', ha.id,
      'question_id', q.id,
      'prompt', q.prompt,
      'question_type', q.question_type,
      'student_answer', COALESCE(sel.text, ha.text_answer),
      'student_option_id', ha.selected_option_id,
      'correct_answer', correct_opts.correct_text,
      'is_correct', COALESCE(ha.is_correct, false),
      'points_awarded', COALESCE(ha.points_awarded, 0),
      'max_points', COALESCE(hq.points, q.default_points),
      'explanation', q.explanation
    )
    ORDER BY hq.order_number, q.created_at
  ), '[]'::jsonb)
  INTO v_answers
  FROM public.homework_answers ha
  JOIN public.questions q ON q.id = ha.question_id
  LEFT JOIN public.homework_questions hq
    ON hq.homework_id = p_homework_id
   AND hq.question_id = q.id
  LEFT JOIN public.question_options sel ON sel.id = ha.selected_option_id
  LEFT JOIN LATERAL (
    SELECT string_agg(qo.text, ', ' ORDER BY qo.order_number) AS correct_text
    FROM public.question_options qo
    WHERE qo.question_id = q.id AND qo.is_correct = true
  ) correct_opts ON true
  WHERE ha.submission_id = v_submission.id;

  RETURN jsonb_build_object(
    'released', true,
    'assessment_type', 'homework',
    'assessment_id', p_homework_id,
    'submission_id', v_submission.id,
    'title', v_submission.title,
    'status', v_submission.status,
    'score', v_submission.score,
    'max_score', v_submission.max_score,
    'teacher_feedback', v_submission.teacher_feedback,
    'submitted_at', v_submission.submitted_at,
    'answers', v_answers
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_exam_review(p_exam_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
  v_attempt RECORD;
  v_answers JSONB;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile not found' USING ERRCODE = '42501';
  END IF;

  SELECT ea.*, e.title, e.result_release_policy
  INTO v_attempt
  FROM public.exam_attempts ea
  JOIN public.exams e ON e.id = ea.exam_id
  WHERE ea.exam_id = p_exam_id
    AND ea.student_id = v_student_id
    AND ea.status IN ('submitted', 'graded', 'expired')
  ORDER BY ea.attempt_number DESC, ea.started_at DESC
  LIMIT 1;

  IF v_attempt.id IS NULL THEN
    RETURN jsonb_build_object('released', false, 'message', 'No finished attempt found');
  END IF;

  IF v_attempt.result_release_policy = 'manual' AND v_attempt.status <> 'graded' THEN
    RETURN jsonb_build_object('released', false, 'message', 'Results are not released yet');
  END IF;

  IF v_attempt.result_release_policy = 'after_exam_window' AND now() < v_attempt.expires_at THEN
    RETURN jsonb_build_object('released', false, 'message', 'Results are not released yet');
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'answer_id', ans.id,
      'question_id', q.id,
      'prompt', q.prompt,
      'question_type', q.question_type,
      'student_answer', COALESCE(sel.text, ans.text_answer),
      'student_option_id', ans.selected_option_id,
      'correct_answer', correct_opts.correct_text,
      'is_correct', COALESCE(ans.is_correct, false),
      'points_awarded', COALESCE(ans.points_awarded, 0),
      'max_points', COALESCE(eq.points, q.default_points),
      'explanation', q.explanation
    )
    ORDER BY eq.order_number, q.created_at
  ), '[]'::jsonb)
  INTO v_answers
  FROM public.exam_answers ans
  JOIN public.questions q ON q.id = ans.question_id
  LEFT JOIN public.exam_questions eq
    ON eq.exam_id = p_exam_id
   AND eq.question_id = q.id
  LEFT JOIN public.question_options sel ON sel.id = ans.selected_option_id
  LEFT JOIN LATERAL (
    SELECT string_agg(qo.text, ', ' ORDER BY qo.order_number) AS correct_text
    FROM public.question_options qo
    WHERE qo.question_id = q.id AND qo.is_correct = true
  ) correct_opts ON true
  WHERE ans.attempt_id = v_attempt.id;

  RETURN jsonb_build_object(
    'released', true,
    'assessment_type', 'exam',
    'assessment_id', p_exam_id,
    'attempt_id', v_attempt.id,
    'attempt_number', v_attempt.attempt_number,
    'title', v_attempt.title,
    'status', v_attempt.status,
    'score', v_attempt.score,
    'max_score', v_attempt.max_score,
    'teacher_feedback', v_attempt.teacher_feedback,
    'submitted_at', v_attempt.submitted_at,
    'answers', v_answers
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.manual_grade_override(
  p_attempt_id UUID,
  p_question_id UUID,
  p_is_correct BOOLEAN,
  p_points NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id UUID;
  v_answer_id UUID;
  v_max_points NUMERIC;
  v_new_score NUMERIC;
BEGIN
  SELECT e.group_id, COALESCE(eq.points, q.default_points), ans.id
  INTO v_group_id, v_max_points, v_answer_id
  FROM public.exam_answers ans
  JOIN public.exam_attempts att ON att.id = ans.attempt_id
  JOIN public.exams e ON e.id = att.exam_id
  JOIN public.questions q ON q.id = ans.question_id
  LEFT JOIN public.exam_questions eq
    ON eq.exam_id = att.exam_id
   AND eq.question_id = ans.question_id
  WHERE ans.attempt_id = p_attempt_id
    AND ans.question_id = p_question_id;

  IF v_answer_id IS NULL THEN
    RAISE EXCEPTION 'Answer not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('exams.grade')
    OR public.current_teacher_assigned_to_group(v_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to override grade' USING ERRCODE = '42501';
  END IF;

  IF p_points < 0 OR p_points > COALESCE(v_max_points, p_points) THEN
    RAISE EXCEPTION 'Points out of bounds' USING ERRCODE = '22003';
  END IF;

  UPDATE public.exam_answers
  SET is_correct = p_is_correct,
      points_awarded = p_points,
      updated_at = now()
  WHERE id = v_answer_id;

  SELECT COALESCE(SUM(points_awarded), 0)
  INTO v_new_score
  FROM public.exam_answers
  WHERE attempt_id = p_attempt_id;

  UPDATE public.exam_attempts
  SET score = v_new_score,
      status = 'graded',
      graded_at = now(),
      graded_by = auth.uid(),
      updated_at = now()
  WHERE id = p_attempt_id;

  RETURN jsonb_build_object(
    'success', true,
    'answer_id', v_answer_id,
    'new_score', v_new_score
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.grade_exam_attempt_with_feedback(
  p_attempt_id UUID,
  p_score NUMERIC,
  p_feedback TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id UUID;
  v_max_score NUMERIC;
  v_result JSONB;
BEGIN
  SELECT e.group_id, a.max_score
  INTO v_group_id, v_max_score
  FROM public.exam_attempts a
  JOIN public.exams e ON e.id = a.exam_id
  WHERE a.id = p_attempt_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Attempt not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('exams.grade')
    OR public.current_teacher_assigned_to_group(v_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to grade exam attempt' USING ERRCODE = '42501';
  END IF;

  IF p_score < 0 OR p_score > COALESCE(v_max_score, p_score) THEN
    RAISE EXCEPTION 'Score out of bounds (0 - %)', v_max_score USING ERRCODE = '22003';
  END IF;

  UPDATE public.exam_attempts
  SET score = p_score,
      teacher_feedback = p_feedback,
      status = 'graded',
      graded_at = now(),
      graded_by = auth.uid(),
      updated_at = now()
  WHERE id = p_attempt_id;

  SELECT to_jsonb(a.*) INTO v_result
  FROM public.exam_attempts a
  WHERE a.id = p_attempt_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_homework_review(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_exam_review(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.manual_grade_override(UUID, UUID, BOOLEAN, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grade_exam_attempt_with_feedback(UUID, NUMERIC, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
