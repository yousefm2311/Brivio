-- Migration: 20260809001000_code_challenge_authoring_runtime.sql
-- Description: Teacher/admin code challenge authoring RPCs and hidden test-case policy hardening.

DROP POLICY IF EXISTS "Code challenge cases readable by lesson access" ON public.code_challenge_test_cases;
CREATE POLICY "Code challenge cases readable by lesson access"
ON public.code_challenge_test_cases FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.code_challenges c
    WHERE c.id = code_challenge_test_cases.challenge_id
      AND c.status = 'published'
      AND (
        (
          code_challenge_test_cases.is_hidden = false
          AND public.current_student_can_access_lesson(c.lesson_id)
        )
        OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
      )
  )
);

DROP FUNCTION IF EXISTS public.get_teacher_lesson_code_challenges(UUID);
CREATE OR REPLACE FUNCTION public.get_teacher_lesson_code_challenges(p_lesson_id UUID)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  difficulty TEXT,
  xp_reward INT,
  status TEXT,
  test_cases JSONB,
  attempts_count BIGINT,
  passed_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.current_user_role() NOT IN ('admin', 'staff', 'super_admin', 'teacher') THEN
    RAISE EXCEPTION 'Unauthorized to manage lesson challenges'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.title::TEXT,
    COALESCE(c.description, '')::TEXT,
    c.difficulty::TEXT,
    c.xp_reward,
    c.status::TEXT,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', tc.id,
          'name', tc.name,
          'stdin', COALESCE(tc.stdin, ''),
          'expected_stdout', tc.expected_stdout,
          'is_hidden', tc.is_hidden,
          'order_number', tc.order_number
        )
        ORDER BY tc.order_number
      ) FILTER (WHERE tc.id IS NOT NULL),
      '[]'::jsonb
    ) AS test_cases,
    COUNT(DISTINCT a.id) AS attempts_count,
    COUNT(DISTINCT a.id) FILTER (WHERE a.status = 'passed') AS passed_count
  FROM public.code_challenges c
  LEFT JOIN public.code_challenge_test_cases tc ON tc.challenge_id = c.id
  LEFT JOIN public.code_challenge_attempts a ON a.challenge_id = c.id
  WHERE c.lesson_id = p_lesson_id
  GROUP BY c.id
  ORDER BY c.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.create_code_challenge_with_cases(UUID, TEXT, TEXT, TEXT, INT, TEXT, JSONB);
CREATE OR REPLACE FUNCTION public.create_code_challenge_with_cases(
  p_lesson_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_difficulty TEXT,
  p_xp_reward INT,
  p_status TEXT,
  p_test_cases JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge_id UUID;
  v_case JSONB;
  v_order INT := 1;
BEGIN
  IF public.current_user_role() NOT IN ('admin', 'staff', 'super_admin', 'teacher') THEN
    RAISE EXCEPTION 'Unauthorized to create code challenges'
      USING ERRCODE = '42501';
  END IF;

  IF COALESCE(NULLIF(TRIM(p_title), ''), '') = '' THEN
    RAISE EXCEPTION 'Challenge title is required' USING ERRCODE = '22023';
  END IF;

  IF jsonb_typeof(COALESCE(p_test_cases, '[]'::jsonb)) <> 'array'
     OR jsonb_array_length(COALESCE(p_test_cases, '[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'At least one test case is required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.code_challenges (
    lesson_id,
    title,
    description,
    difficulty,
    xp_reward,
    status,
    created_by
  )
  VALUES (
    p_lesson_id,
    TRIM(p_title),
    NULLIF(TRIM(COALESCE(p_description, '')), ''),
    COALESCE(NULLIF(p_difficulty, ''), 'medium'),
    GREATEST(0, COALESCE(p_xp_reward, 50)),
    COALESCE(NULLIF(p_status, ''), 'published'),
    auth.uid()
  )
  RETURNING id INTO v_challenge_id;

  FOR v_case IN SELECT * FROM jsonb_array_elements(p_test_cases)
  LOOP
    IF COALESCE(NULLIF(TRIM(v_case->>'expected_stdout'), ''), '') = '' THEN
      RAISE EXCEPTION 'Expected output is required for every test case'
        USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.code_challenge_test_cases (
      challenge_id,
      name,
      stdin,
      expected_stdout,
      is_hidden,
      order_number
    )
    VALUES (
      v_challenge_id,
      COALESCE(NULLIF(TRIM(v_case->>'name'), ''), 'Case ' || v_order),
      COALESCE(v_case->>'stdin', ''),
      v_case->>'expected_stdout',
      COALESCE((v_case->>'is_hidden')::BOOLEAN, false),
      v_order
    );
    v_order := v_order + 1;
  END LOOP;

  RETURN v_challenge_id;
END;
$$;

DROP FUNCTION IF EXISTS public.update_code_challenge_status(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.update_code_challenge_status(
  p_challenge_id UUID,
  p_status TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.current_user_role() NOT IN ('admin', 'staff', 'super_admin', 'teacher') THEN
    RAISE EXCEPTION 'Unauthorized to update code challenges'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.code_challenges
  SET status = p_status,
      updated_at = NOW()
  WHERE id = p_challenge_id
    AND p_status IN ('draft', 'published', 'archived');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Challenge not found or invalid status'
      USING ERRCODE = 'P0002';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_teacher_lesson_code_challenges(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_code_challenge_with_cases(UUID, TEXT, TEXT, TEXT, INT, TEXT, JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_code_challenge_status(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_lesson_code_challenges(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_code_challenge_with_cases(UUID, TEXT, TEXT, TEXT, INT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_code_challenge_status(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
