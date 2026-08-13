-- Parent exam visibility, answer review, and guardian assessment notifications.

CREATE OR REPLACE FUNCTION public.parent_can_access_student(p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.parents p
    JOIN public.parent_students ps ON ps.parent_id = p.id
    WHERE p.profile_id = auth.uid()
      AND ps.student_id = p_student_id
  );
$$;

CREATE OR REPLACE FUNCTION public.get_parent_child_exam_feed(p_student_id UUID)
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
  group_name TEXT,
  attempt_count INT,
  last_attempt_status TEXT,
  last_score NUMERIC,
  max_score NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.parent_can_access_student(p_student_id) THEN
    RAISE EXCEPTION 'Parent account is not linked to this student' USING ERRCODE = '42501';
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
    ex.status,
    ex.result_release_policy,
    COALESCE(g.name, 'Group')::TEXT AS group_name,
    COALESCE(att_stats.attempt_count, 0)::INT AS attempt_count,
    att_stats.last_attempt_status,
    att_stats.last_score,
    att_stats.max_score
  FROM public.exams ex
  JOIN public.groups g ON g.id = ex.group_id
  JOIN public.enrollments e ON e.group_id = ex.group_id
  LEFT JOIN LATERAL (
    SELECT
      COUNT(*)::INT AS attempt_count,
      (ARRAY_AGG(a.status ORDER BY a.created_at DESC))[1] AS last_attempt_status,
      (ARRAY_AGG(a.score ORDER BY a.created_at DESC))[1] AS last_score,
      (ARRAY_AGG(a.max_score ORDER BY a.created_at DESC))[1] AS max_score
    FROM public.exam_attempts a
    WHERE a.exam_id = ex.id
      AND a.student_id = p_student_id
  ) att_stats ON true
  WHERE e.student_id = p_student_id
    AND e.status = 'active'
    AND ex.status = 'published'
  ORDER BY ex.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_parent_child_exam_review(
  p_student_id UUID,
  p_exam_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_attempt RECORD;
  v_answers JSONB;
BEGIN
  IF NOT public.parent_can_access_student(p_student_id) THEN
    RAISE EXCEPTION 'Parent account is not linked to this student' USING ERRCODE = '42501';
  END IF;

  SELECT ea.*, e.title, e.result_release_policy
  INTO v_attempt
  FROM public.exam_attempts ea
  JOIN public.exams e ON e.id = ea.exam_id
  WHERE ea.exam_id = p_exam_id
    AND ea.student_id = p_student_id
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
    WHERE qo.question_id = q.id
      AND qo.is_correct = true
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

CREATE OR REPLACE FUNCTION public.notify_parents_on_exam_published()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status <> 'published' THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
  SELECT DISTINCT
    p.profile_id,
    'New exam published',
    'A new exam "' || NEW.title || '" is available for your child.',
    'exam',
    NEW.id
  FROM public.enrollments e
  JOIN public.parent_students ps ON ps.student_id = e.student_id
  JOIN public.parents p ON p.id = ps.parent_id
  WHERE e.group_id = NEW.group_id
    AND e.status = 'active'
    AND p.profile_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.app_notifications n
      WHERE n.user_id = p.profile_id
        AND n.type = 'exam'
        AND n.reference_id = NEW.id
        AND n.title = 'New exam published'
    );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_parents_on_exam_published_trigger ON public.exams;
CREATE TRIGGER notify_parents_on_exam_published_trigger
AFTER INSERT OR UPDATE OF status ON public.exams
FOR EACH ROW
EXECUTE FUNCTION public.notify_parents_on_exam_published();

CREATE OR REPLACE FUNCTION public.notify_parents_on_exam_graded()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title TEXT;
BEGIN
  IF NEW.status <> 'graded' THEN
    RETURN NEW;
  END IF;

  SELECT title INTO v_title FROM public.exams WHERE id = NEW.exam_id;

  INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
  SELECT DISTINCT
    p.profile_id,
    'Exam graded',
    'Your child exam "' || COALESCE(v_title, 'Exam') || '" has been graded. Score: ' || COALESCE(NEW.score::TEXT, 'N/A'),
    'grade',
    NEW.exam_id
  FROM public.parent_students ps
  JOIN public.parents p ON p.id = ps.parent_id
  WHERE ps.student_id = NEW.student_id
    AND p.profile_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.app_notifications n
      WHERE n.user_id = p.profile_id
        AND n.type = 'grade'
        AND n.reference_id = NEW.exam_id
        AND n.title = 'Exam graded'
    );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_parents_on_exam_graded_trigger ON public.exam_attempts;
CREATE TRIGGER notify_parents_on_exam_graded_trigger
AFTER INSERT OR UPDATE OF status, score ON public.exam_attempts
FOR EACH ROW
EXECUTE FUNCTION public.notify_parents_on_exam_graded();

INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
SELECT DISTINCT
  p.profile_id,
  'New exam published',
  'A new exam "' || ex.title || '" is available for your child.',
  'exam',
  ex.id
FROM public.exams ex
JOIN public.enrollments e ON e.group_id = ex.group_id AND e.status = 'active'
JOIN public.parent_students ps ON ps.student_id = e.student_id
JOIN public.parents p ON p.id = ps.parent_id
WHERE ex.status = 'published'
  AND p.profile_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.app_notifications n
    WHERE n.user_id = p.profile_id
      AND n.type = 'exam'
      AND n.reference_id = ex.id
      AND n.title = 'New exam published'
  );

INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
SELECT DISTINCT
  p.profile_id,
  'Exam graded',
  'Your child exam "' || COALESCE(ex.title, 'Exam') || '" has been graded. Score: ' || COALESCE(ea.score::TEXT, 'N/A'),
  'grade',
  ex.id
FROM public.exam_attempts ea
JOIN public.exams ex ON ex.id = ea.exam_id
JOIN public.parent_students ps ON ps.student_id = ea.student_id
JOIN public.parents p ON p.id = ps.parent_id
WHERE ea.status = 'graded'
  AND p.profile_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.app_notifications n
    WHERE n.user_id = p.profile_id
      AND n.type = 'grade'
      AND n.reference_id = ex.id
      AND n.title = 'Exam graded'
  );

REVOKE EXECUTE ON FUNCTION public.parent_can_access_student(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_parent_child_exam_feed(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_parent_child_exam_review(UUID, UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.parent_can_access_student(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_parent_child_exam_feed(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_parent_child_exam_review(UUID, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
