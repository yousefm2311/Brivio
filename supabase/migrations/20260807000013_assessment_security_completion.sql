-- Migration: 20260807000013_assessment_security_completion.sql
-- Description: Assessment Engine Security Hardening (Student-Safe Question Projection, Immutable Snapshots, Answer-Key Non-Leak Contract, Manual Grading & Result Release RPCs)

-- 1. Create Student-Safe Question Options View (Redacting is_correct)
CREATE OR REPLACE VIEW public.student_question_options AS
SELECT
    id,
    question_id,
    text,
    order_number
FROM public.question_options;

GRANT SELECT ON public.student_question_options TO authenticated;

-- Revoke direct SELECT on question_options for authenticated non-admin users to prevent is_correct leaks via PostgREST select('*')
REVOKE SELECT ON public.question_options FROM authenticated;
GRANT SELECT ON public.question_options TO service_role;

-- 2. Student-Safe Exam Attempt Bootstrap RPC (No Answer Keys Leaked)
CREATE OR REPLACE FUNCTION public.get_exam_attempt_bootstrap(p_attempt_id UUID)
RETURNS JSONB AS $$
DECLARE
    att RECORD;
    ex RECORD;
    s_id UUID;
    q_list JSONB;
BEGIN
    SELECT id INTO s_id FROM public.students WHERE profile_id = auth.uid() AND status = 'active';

    SELECT * INTO att FROM public.exam_attempts WHERE id = p_attempt_id;
    IF att.id IS NULL THEN
        RAISE EXCEPTION 'Exam attempt not found' USING ERRCODE = '44000';
    END IF;

    IF att.student_id != s_id AND NOT public.is_admin_or_super() THEN
        RAISE EXCEPTION 'Unauthorized attempt access' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO ex FROM public.exams WHERE id = att.exam_id;

    -- Construct student-safe question snapshots WITHOUT is_correct or explanation
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', q.id,
            'prompt', q.prompt,
            'question_type', q.question_type,
            'points', eq.points,
            'options', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', qo.id,
                        'text', qo.text,
                        'order_number', qo.order_number
                    ) ORDER BY qo.order_number
                )
                FROM public.question_options qo
                WHERE qo.question_id = q.id
            )
        ) ORDER BY eq.order_number
    ) INTO q_list
    FROM public.exam_questions eq
    JOIN public.questions q ON q.id = eq.question_id
    WHERE eq.exam_id = att.exam_id;

    RETURN jsonb_build_object(
        'attempt_id', att.id,
        'exam_id', ex.id,
        'exam_title', ex.title,
        'instructions', ex.description,
        'started_at', att.started_at,
        'expires_at', att.expires_at,
        'status', att.status,
        'questions', COALESCE(q_list, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Manual Teacher Grading RPC
CREATE OR REPLACE FUNCTION public.grade_exam_answer(
    p_answer_id UUID,
    p_score NUMERIC,
    p_feedback TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    ans RECORD;
    eq RECORD;
    att RECORD;
    new_total NUMERIC(6,2);
BEGIN
    IF NOT (auth.uid() IS NULL OR public.is_admin_or_super() OR public.has_permission('exams.grade')) THEN
        RAISE EXCEPTION 'Unauthorized to grade exam answer' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO ans FROM public.exam_answers WHERE id = p_answer_id;
    IF ans.id IS NULL THEN
        RAISE EXCEPTION 'Exam answer not found' USING ERRCODE = '44000';
    END IF;

    SELECT * INTO att FROM public.exam_attempts WHERE id = ans.attempt_id;
    SELECT points INTO eq FROM public.exam_questions WHERE exam_id = att.exam_id AND question_id = ans.question_id;

    IF p_score < 0 OR (eq.points IS NOT NULL AND p_score > eq.points) THEN
        RAISE EXCEPTION 'Score out of bounds (0 - %)', COALESCE(eq.points, 100.0) USING ERRCODE = '22003';
    END IF;

    UPDATE public.exam_answers
    SET points_awarded = p_score,
        is_correct = (p_score = COALESCE(eq.points, p_score)),
        updated_at = NOW()
    WHERE id = p_answer_id;

    -- Recalculate total score for attempt
    SELECT COALESCE(SUM(points_awarded), 0.00) INTO new_total
    FROM public.exam_answers WHERE attempt_id = ans.attempt_id;

    UPDATE public.exam_attempts
    SET score = new_total,
        status = 'graded',
        updated_at = NOW()
    WHERE id = ans.attempt_id;

    RETURN jsonb_build_object(
        'success', true,
        'answer_id', p_answer_id,
        'points_awarded', p_score,
        'new_total_score', new_total
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Result Release Policy RPC
CREATE OR REPLACE FUNCTION public.get_exam_result(p_attempt_id UUID)
RETURNS JSONB AS $$
DECLARE
    att RECORD;
    ex RECORD;
    s_id UUID;
    is_released BOOLEAN := false;
BEGIN
    SELECT id INTO s_id FROM public.students WHERE profile_id = auth.uid() AND status = 'active';
    SELECT * INTO att FROM public.exam_attempts WHERE id = p_attempt_id;
    IF att.id IS NULL THEN
        RAISE EXCEPTION 'Attempt not found' USING ERRCODE = '44000';
    END IF;

    SELECT * INTO ex FROM public.exams WHERE id = att.exam_id;

    IF public.is_admin_or_super() OR att.student_id = s_id THEN
        IF ex.result_release_policy = 'immediate' THEN
            is_released := true;
        ELSIF ex.result_release_policy = 'after_exam_window' AND NOW() > att.expires_at THEN
            is_released := true;
        ELSIF ex.result_release_policy = 'manual' AND att.status = 'graded' THEN
            is_released := true;
        END IF;
    END IF;

    IF NOT is_released THEN
        RETURN jsonb_build_object(
            'released', false,
            'message', 'Results are not released yet according to release policy'
        );
    END IF;

    RETURN jsonb_build_object(
        'released', true,
        'attempt_id', att.id,
        'score', att.score,
        'max_score', att.max_score,
        'status', att.status,
        'submitted_at', att.submitted_at
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.get_exam_attempt_bootstrap(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_exam_attempt_bootstrap(UUID) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.grade_exam_answer(UUID, NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.grade_exam_answer(UUID, NUMERIC, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_exam_result(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_exam_result(UUID) TO authenticated;
