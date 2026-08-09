-- Migration: 20260809000800_code_challenges_runtime.sql
-- Description: Lesson code challenges with test cases and student attempts.

CREATE TABLE IF NOT EXISTS public.code_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  difficulty TEXT NOT NULL DEFAULT 'medium' CHECK (difficulty IN ('easy', 'medium', 'hard')),
  xp_reward INT NOT NULL DEFAULT 50 CHECK (xp_reward >= 0),
  status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'archived')),
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.code_challenge_test_cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES public.code_challenges(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT 'Case',
  stdin TEXT,
  expected_stdout TEXT NOT NULL,
  is_hidden BOOLEAN NOT NULL DEFAULT false,
  order_number INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.code_challenge_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES public.code_challenges(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  language TEXT NOT NULL CHECK (language IN ('python', 'cpp')),
  source_code TEXT NOT NULL,
  passed_cases INT NOT NULL DEFAULT 0 CHECK (passed_cases >= 0),
  total_cases INT NOT NULL DEFAULT 0 CHECK (total_cases >= 0),
  status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'passed', 'failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_code_challenges_lesson_status
ON public.code_challenges(lesson_id, status);

CREATE INDEX IF NOT EXISTS idx_code_challenge_attempts_student
ON public.code_challenge_attempts(student_id, challenge_id, created_at DESC);

ALTER TABLE public.code_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.code_challenge_test_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.code_challenge_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Code challenges readable by lesson access" ON public.code_challenges;
CREATE POLICY "Code challenges readable by lesson access"
ON public.code_challenges FOR SELECT TO authenticated USING (
  status = 'published'
  AND (
    public.current_student_can_access_lesson(lesson_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
  )
);

DROP POLICY IF EXISTS "Code challenge cases readable by lesson access" ON public.code_challenge_test_cases;
CREATE POLICY "Code challenge cases readable by lesson access"
ON public.code_challenge_test_cases FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.code_challenges c
    WHERE c.id = code_challenge_test_cases.challenge_id
      AND c.status = 'published'
      AND (
        public.current_student_can_access_lesson(c.lesson_id)
        OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
      )
  )
);

DROP POLICY IF EXISTS "Code challenge attempts readable by owner and staff" ON public.code_challenge_attempts;
CREATE POLICY "Code challenge attempts readable by owner and staff"
ON public.code_challenge_attempts FOR SELECT TO authenticated USING (
  student_id = public.current_student_id()
  OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
);

DROP POLICY IF EXISTS "Code challenge attempts inserted by owner" ON public.code_challenge_attempts;
CREATE POLICY "Code challenge attempts inserted by owner"
ON public.code_challenge_attempts FOR INSERT TO authenticated WITH CHECK (
  student_id = public.current_student_id()
);

DROP FUNCTION IF EXISTS public.get_lesson_code_challenges(UUID);
CREATE OR REPLACE FUNCTION public.get_lesson_code_challenges(p_lesson_id UUID)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  difficulty TEXT,
  xp_reward INT,
  test_cases JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.current_student_can_access_lesson(p_lesson_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view lesson challenges'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.title::TEXT,
    COALESCE(c.description, '')::TEXT,
    c.difficulty::TEXT,
    c.xp_reward,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'name', tc.name,
          'stdin', COALESCE(tc.stdin, ''),
          'expected_stdout', tc.expected_stdout
        )
        ORDER BY tc.order_number
      ) FILTER (WHERE tc.id IS NOT NULL),
      '[]'::jsonb
    ) AS test_cases
  FROM public.code_challenges c
  LEFT JOIN public.code_challenge_test_cases tc
    ON tc.challenge_id = c.id
   AND tc.is_hidden = false
  WHERE c.lesson_id = p_lesson_id
    AND c.status = 'published'
  GROUP BY c.id
  ORDER BY c.difficulty, c.created_at;
END;
$$;

DROP FUNCTION IF EXISTS public.submit_code_challenge_result(UUID, TEXT, TEXT, INT, INT);
CREATE OR REPLACE FUNCTION public.submit_code_challenge_result(
  p_challenge_id UUID,
  p_language TEXT,
  p_source_code TEXT,
  p_passed_cases INT,
  p_total_cases INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
  v_challenge RECORD;
  v_status TEXT;
  v_attempt_id UUID;
  v_awarded_xp INT := 0;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_challenge
  FROM public.code_challenges
  WHERE id = p_challenge_id
    AND status = 'published';

  IF v_challenge.id IS NULL THEN
    RAISE EXCEPTION 'Challenge not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.current_student_can_access_lesson(v_challenge.lesson_id) THEN
    RAISE EXCEPTION 'Unauthorized to submit this challenge'
      USING ERRCODE = '42501';
  END IF;

  v_status := CASE
    WHEN p_total_cases > 0 AND p_passed_cases >= p_total_cases THEN 'passed'
    ELSE 'failed'
  END;

  INSERT INTO public.code_challenge_attempts (
    challenge_id,
    student_id,
    language,
    source_code,
    passed_cases,
    total_cases,
    status
  ) VALUES (
    p_challenge_id,
    v_student_id,
    p_language,
    p_source_code,
    GREATEST(0, p_passed_cases),
    GREATEST(0, p_total_cases),
    v_status
  )
  RETURNING id INTO v_attempt_id;

  IF v_status = 'passed' THEN
    INSERT INTO public.student_xp_events (
      student_id,
      event_type,
      reference_table,
      reference_id,
      xp_amount
    )
    SELECT
      v_student_id,
      'code_challenge_passed',
      'code_challenges',
      p_challenge_id,
      v_challenge.xp_reward
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.student_xp_events
      WHERE student_id = v_student_id
        AND event_type = 'code_challenge_passed'
        AND reference_table = 'code_challenges'
        AND reference_id = p_challenge_id
    );
    GET DIAGNOSTICS v_awarded_xp = ROW_COUNT;
    v_awarded_xp := v_awarded_xp * v_challenge.xp_reward;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', v_attempt_id,
    'status', v_status,
    'awarded_xp', v_awarded_xp
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_lesson_code_challenges(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_code_challenge_result(UUID, TEXT, TEXT, INT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_lesson_code_challenges(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_code_challenge_result(UUID, TEXT, TEXT, INT, INT) TO authenticated;

NOTIFY pgrst, 'reload schema';
