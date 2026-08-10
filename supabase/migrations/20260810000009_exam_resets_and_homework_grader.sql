-- 1. Exam Reset Requests Table and Exam Attempts Feedback
ALTER TABLE public.exam_attempts 
ADD COLUMN IF NOT EXISTS teacher_feedback TEXT,
ADD COLUMN IF NOT EXISTS graded_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS graded_by UUID REFERENCES auth.users(id);

CREATE TABLE IF NOT EXISTS public.exam_reset_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_pending_reset_request UNIQUE (exam_id, student_id, status) DEFERRABLE INITIALLY DEFERRED
);

ALTER TABLE public.exam_reset_requests ENABLE ROW LEVEL SECURITY;

-- FIXED: Added DROP POLICY IF EXISTS
DROP POLICY IF EXISTS "Students can view and create their own reset requests" ON public.exam_reset_requests;
DROP POLICY IF EXISTS "Teachers can view and manage reset requests for their exams" ON public.exam_reset_requests;

CREATE POLICY "Students can view and create their own reset requests" 
ON public.exam_reset_requests FOR ALL TO authenticated 
USING (
    EXISTS (SELECT 1 FROM public.students s WHERE s.id = exam_reset_requests.student_id AND s.profile_id = auth.uid())
);

CREATE POLICY "Teachers can view and manage reset requests for their exams" 
ON public.exam_reset_requests FOR ALL TO authenticated 
USING (
    public.is_admin_or_super() OR
    EXISTS (
        SELECT 1 FROM public.exams e 
        WHERE e.id = exam_reset_requests.exam_id 
        AND public.current_teacher_assigned_to_group(e.group_id)
    )
);

CREATE OR REPLACE FUNCTION public.request_exam_reset(p_exam_id UUID, p_reason TEXT)
RETURNS VOID AS $$
DECLARE
    v_student_id UUID := public.current_student_id();
BEGIN
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Student profile not found' USING ERRCODE = '42501';
    END IF;
    
    INSERT INTO public.exam_reset_requests (exam_id, student_id, reason, status, created_at, updated_at)
    VALUES (p_exam_id, v_student_id, p_reason, 'pending', NOW(), NOW())
    ON CONFLICT (exam_id, student_id, status) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION public.request_exam_reset(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_exam_reset(UUID, TEXT) TO authenticated;

-- 2. Homework Auto-Grading (MCQ)
CREATE OR REPLACE FUNCTION public.submit_homework_mcq(p_homework_id UUID, p_answers JSONB)
RETURNS JSONB AS $$
DECLARE
    v_student_id UUID := public.current_student_id();
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

    -- Get or create submission
    INSERT INTO public.homework_submissions (homework_id, student_id, status, submitted_at, updated_at)
    VALUES (p_homework_id, v_student_id, 'submitted', NOW(), NOW())
    ON CONFLICT (homework_id, student_id) DO UPDATE 
    SET status = 'submitted', submitted_at = NOW(), updated_at = NOW()
    RETURNING id INTO v_submission_id;

    -- Clear old answers if retrying
    DELETE FROM public.homework_answers WHERE submission_id = v_submission_id;

    -- Evaluate MCQ
    FOR ans IN SELECT * FROM jsonb_each_text(p_answers) LOOP
        q_id := ans.key::UUID;
        o_id := ans.value::UUID;
        
        SELECT is_correct INTO opt_correct FROM public.question_options WHERE id = o_id;
        SELECT points INTO q_points FROM public.homework_questions WHERE homework_id = p_homework_id AND question_id = q_id;
        
        IF opt_correct = true THEN
            v_score := v_score + COALESCE(q_points, 1.00);
            INSERT INTO public.homework_answers (submission_id, question_id, selected_option_id, is_correct, points_awarded)
            VALUES (v_submission_id, q_id, o_id, true, COALESCE(q_points, 1.00));
        ELSE
            INSERT INTO public.homework_answers (submission_id, question_id, selected_option_id, is_correct, points_awarded)
            VALUES (v_submission_id, q_id, o_id, false, 0.00);
        END IF;
    END LOOP;

    -- Get max score
    SELECT max_score INTO v_max_score FROM public.homework WHERE id = p_homework_id;

    -- Update final score
    UPDATE public.homework_submissions
    SET score = v_score, status = 'graded'
    WHERE id = v_submission_id;

    RETURN jsonb_build_object(
        'success', true,
        'submission_id', v_submission_id,
        'score', v_score,
        'max_score', v_max_score
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Update Question with Options (safe update)
CREATE OR REPLACE FUNCTION public.update_question_with_options(
    p_question_id UUID,
    p_prompt TEXT,
    p_explanation TEXT,
    p_default_points NUMERIC,
    p_options JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_teacher_id UUID := public.current_teacher_id();
    opt RECORD;
BEGIN
    IF v_teacher_id IS NULL AND NOT public.is_admin_or_super() THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    -- Update question
    UPDATE public.questions
    SET prompt = p_prompt,
        explanation = p_explanation,
        default_points = p_default_points,
        updated_at = NOW()
    WHERE id = p_question_id;

    -- Update options
    FOR opt IN SELECT * FROM jsonb_array_elements(p_options) LOOP
        UPDATE public.question_options
        SET text = (opt.value->>'text')::TEXT,
            is_correct = (opt.value->>'is_correct')::BOOLEAN,
            updated_at = NOW()
        WHERE question_id = p_question_id AND order_number = (opt.value->>'order_number')::INT;
    END LOOP;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION public.update_question_with_options(UUID, TEXT, TEXT, NUMERIC, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_question_with_options(UUID, TEXT, TEXT, NUMERIC, JSONB) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.submit_homework_mcq(UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_homework_mcq(UUID, JSONB) TO authenticated;

-- 3. Update Teacher Grading Queue to include Exams
DROP FUNCTION IF EXISTS public.get_teacher_grading_queue(UUID);

CREATE OR REPLACE FUNCTION public.get_teacher_grading_queue(p_teacher_id UUID)
RETURNS TABLE (
  id UUID,
  assessment_id UUID,
  student_id UUID,
  status TEXT,
  score NUMERIC,
  submitted_at TIMESTAMPTZ,
  max_score NUMERIC,
  assessment_title TEXT,
  group_id UUID,
  student_full_name TEXT,
  student_email TEXT,
  submission_text TEXT,
  attachment_url TEXT,
  assessment_type TEXT
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
    hs.homework_id AS assessment_id,
    hs.student_id,
    COALESCE(hs.status, 'submitted')::TEXT AS status,
    hs.score,
    hs.submitted_at,
    h.max_score,
    COALESCE(h.title, 'Homework')::TEXT AS assessment_title,
    h.group_id,
    COALESCE(p.full_name, 'Student')::TEXT AS student_full_name,
    COALESCE(p.email, '')::TEXT AS student_email,
    hs.submission_text,
    hs.attachment_url,
    'homework'::TEXT AS assessment_type
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
  UNION ALL
  SELECT
    ea.id,
    ea.exam_id AS assessment_id,
    ea.student_id,
    COALESCE(ea.status, 'submitted')::TEXT AS status,
    ea.score,
    ea.submitted_at,
    ea.max_score,
    COALESCE(e.title, 'Exam')::TEXT AS assessment_title,
    e.group_id,
    COALESCE(p.full_name, 'Student')::TEXT AS student_full_name,
    COALESCE(p.email, '')::TEXT AS student_email,
    NULL::TEXT AS submission_text,
    NULL::TEXT AS attachment_url,
    'exam'::TEXT AS assessment_type
  FROM public.exam_attempts ea
  JOIN public.exams e ON e.id = ea.exam_id
  JOIN public.students s ON s.id = ea.student_id
  LEFT JOIN public.profiles p ON p.id = s.profile_id
  WHERE ea.status IN ('submitted', 'graded') 
  AND e.group_id IN (
    SELECT gt.group_id
    FROM public.group_teachers gt
    WHERE gt.teacher_id = p_teacher_id
      AND gt.effective_from <= CURRENT_DATE
      AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
  )
  ORDER BY submitted_at DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_teacher_grading_queue(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_grading_queue(UUID) TO authenticated;

-- 4. Grade Exam Attempt With Feedback
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
  SELECT e.group_id, e.max_score
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

  IF p_score < 0 OR p_score > v_max_score THEN
    RAISE EXCEPTION 'Score out of bounds (0 - %)', v_max_score USING ERRCODE = '22003';
  END IF;

  UPDATE public.exam_attempts
  SET score = p_score,
      teacher_feedback = p_feedback,
      status = 'graded',
      graded_at = NOW(),
      graded_by = auth.uid(),
      updated_at = NOW()
  WHERE id = p_attempt_id;

  SELECT to_jsonb(a.*) INTO v_result
  FROM public.exam_attempts a
  WHERE a.id = p_attempt_id;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.grade_exam_attempt_with_feedback(UUID, NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.grade_exam_attempt_with_feedback(UUID, NUMERIC, TEXT) TO authenticated;