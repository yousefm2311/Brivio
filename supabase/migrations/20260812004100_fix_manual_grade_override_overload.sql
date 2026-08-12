-- Fix PostgREST ambiguity caused by overloaded manual_grade_override functions.

DROP FUNCTION IF EXISTS public.manual_grade_override(UUID, UUID, BOOLEAN, DOUBLE PRECISION);
DROP FUNCTION IF EXISTS public.manual_grade_override(UUID, UUID, BOOLEAN, NUMERIC);

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
      updated_at = NOW()
  WHERE id = v_answer_id;

  SELECT COALESCE(SUM(points_awarded), 0)
  INTO v_new_score
  FROM public.exam_answers
  WHERE attempt_id = p_attempt_id;

  UPDATE public.exam_attempts
  SET score = v_new_score,
      status = 'graded',
      graded_at = NOW(),
      graded_by = auth.uid(),
      updated_at = NOW()
  WHERE id = p_attempt_id;

  RETURN jsonb_build_object(
    'success', true,
    'answer_id', v_answer_id,
    'new_score', v_new_score
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.manual_grade_override(UUID, UUID, BOOLEAN, NUMERIC) TO authenticated;

NOTIFY pgrst, 'reload schema';
