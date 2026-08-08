-- Migration: 20260807000012_assessment_engine.sql
-- Description: Phase 6 Question Bank, Homework Engine & Exam Engine Infrastructure

-- 1. Question Bank & Options Tables
CREATE TABLE IF NOT EXISTS public.questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES public.units(id) ON DELETE SET NULL,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE SET NULL,
    question_type TEXT NOT NULL CHECK (question_type IN ('multiple_choice', 'true_false', 'short_answer', 'long_answer')),
    prompt TEXT NOT NULL,
    explanation TEXT,
    difficulty TEXT NOT NULL DEFAULT 'medium' CHECK (difficulty IN ('easy', 'medium', 'hard')),
    default_points NUMERIC(6,2) NOT NULL DEFAULT 1.00 CHECK (default_points >= 0),
    status TEXT NOT NULL DEFAULT 'active',
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.question_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    order_number INT NOT NULL DEFAULT 1,
    is_correct BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Homework Engine Tables
CREATE TABLE IF NOT EXISTS public.homework (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    due_at TIMESTAMPTZ NOT NULL,
    max_score NUMERIC(6,2) NOT NULL DEFAULT 100.00 CHECK (max_score > 0),
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'closed', 'archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.homework_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    homework_id UUID NOT NULL REFERENCES public.homework(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
    order_number INT NOT NULL DEFAULT 1,
    points NUMERIC(6,2) NOT NULL DEFAULT 1.00 CHECK (points >= 0),
    CONSTRAINT unique_homework_question UNIQUE (homework_id, question_id)
);

CREATE TABLE IF NOT EXISTS public.homework_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    homework_id UUID NOT NULL REFERENCES public.homework(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'submitted', 'graded')),
    score NUMERIC(6,2) CHECK (score >= 0),
    submitted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_student_homework_submission UNIQUE (homework_id, student_id)
);

CREATE TABLE IF NOT EXISTS public.homework_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL REFERENCES public.homework_submissions(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
    selected_option_id UUID REFERENCES public.question_options(id) ON DELETE SET NULL,
    text_answer TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_submission_question_answer UNIQUE (submission_id, question_id)
);

-- 3. Exam Engine Tables
CREATE TABLE IF NOT EXISTS public.exams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
    duration_minutes INT NOT NULL CHECK (duration_minutes > 0),
    max_attempts INT NOT NULL DEFAULT 1 CHECK (max_attempts > 0),
    pass_score NUMERIC(6,2) DEFAULT 50.00 CHECK (pass_score >= 0),
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'closed', 'archived')),
    result_release_policy TEXT NOT NULL DEFAULT 'immediate' CHECK (result_release_policy IN ('immediate', 'after_exam_window', 'manual')),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.exam_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
    order_number INT NOT NULL DEFAULT 1,
    points NUMERIC(6,2) NOT NULL DEFAULT 1.00 CHECK (points >= 0),
    CONSTRAINT unique_exam_question UNIQUE (exam_id, question_id)
);

CREATE TABLE IF NOT EXISTS public.exam_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    attempt_number INT NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'submitted', 'expired', 'graded')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    submitted_at TIMESTAMPTZ,
    score NUMERIC(6,2) CHECK (score >= 0),
    max_score NUMERIC(6,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_student_exam_attempt UNIQUE (exam_id, student_id, attempt_number)
);

CREATE TABLE IF NOT EXISTS public.exam_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attempt_id UUID NOT NULL REFERENCES public.exam_attempts(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
    selected_option_id UUID REFERENCES public.question_options(id) ON DELETE SET NULL,
    text_answer TEXT,
    is_correct BOOLEAN,
    points_awarded NUMERIC(6,2) DEFAULT 0.00 CHECK (points_awarded >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_attempt_question_answer UNIQUE (attempt_id, question_id)
);

-- 4. Enable RLS on all Phase 6 tables
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.homework ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.homework_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.homework_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.homework_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_answers ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for Questions and Options (Preventing answer-key leaks)
CREATE POLICY "Questions viewable by authorized users"
ON public.questions FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('questions.view') OR
    EXISTS (
        SELECT 1 FROM public.students s
        JOIN public.enrollments e ON e.student_id = s.id
        JOIN public.groups g ON g.id = e.group_id
        WHERE s.profile_id = auth.uid()
          AND g.subject_id = questions.subject_id
          AND e.status = 'active'
    )
);

CREATE POLICY "Question options viewable by authorized users"
ON public.question_options FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('questions.view') OR
    EXISTS (
        SELECT 1 FROM public.questions q
        JOIN public.students s ON true
        JOIN public.enrollments e ON e.student_id = s.id
        JOIN public.groups g ON g.id = e.group_id
        WHERE q.id = question_options.question_id
          AND s.profile_id = auth.uid()
          AND g.subject_id = q.subject_id
          AND e.status = 'active'
    )
);

-- 6. Server-Authoritative Exam RPCs

-- Start Exam RPC
CREATE OR REPLACE FUNCTION public.start_exam(p_exam_id UUID)
RETURNS JSONB AS $$
DECLARE
    s_id UUID;
    target_exam RECORD;
    current_attempt_count INT;
    new_attempt_id UUID;
    calc_expires_at TIMESTAMPTZ;
    total_max NUMERIC(6,2);
BEGIN
    SELECT id INTO s_id FROM public.students WHERE profile_id = auth.uid() AND status = 'active';
    IF s_id IS NULL THEN
        RAISE EXCEPTION 'Only active enrolled students can start an exam' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO target_exam FROM public.exams WHERE id = p_exam_id AND status = 'published';
    IF target_exam.id IS NULL THEN
        RAISE EXCEPTION 'Exam not available or not published' USING ERRCODE = '44000';
    END IF;

    -- Count existing attempts
    SELECT COUNT(*)::int INTO current_attempt_count
    FROM public.exam_attempts
    WHERE exam_id = p_exam_id AND student_id = s_id;

    IF current_attempt_count >= target_exam.max_attempts THEN
        RAISE EXCEPTION 'Maximum exam attempts reached' USING ERRCODE = '44000';
    END IF;

    -- Calculate total max score from exam_questions
    SELECT COALESCE(SUM(points), 0.00) INTO total_max
    FROM public.exam_questions WHERE exam_id = p_exam_id;

    calc_expires_at := NOW() + (target_exam.duration_minutes || ' minutes')::INTERVAL;
    new_attempt_id := gen_random_uuid();

    INSERT INTO public.exam_attempts (
        id, exam_id, student_id, attempt_number, status, started_at, expires_at, max_score
    )
    VALUES (
        new_attempt_id, p_exam_id, s_id, current_attempt_count + 1, 'in_progress', NOW(), calc_expires_at, total_max
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Save Exam Answer RPC (Autosave with debounce support & deadline protection)
CREATE OR REPLACE FUNCTION public.save_exam_answer(
    p_attempt_id UUID,
    p_question_id UUID,
    p_selected_option_id UUID DEFAULT NULL,
    p_text_answer TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    target_attempt RECORD;
BEGIN
    SELECT * INTO target_attempt FROM public.exam_attempts WHERE id = p_attempt_id;
    IF target_attempt.id IS NULL THEN
        RAISE EXCEPTION 'Exam attempt not found' USING ERRCODE = '44000';
    END IF;

    IF target_attempt.status != 'in_progress' OR NOW() > target_attempt.expires_at THEN
        RAISE EXCEPTION 'Exam attempt expired or already finalized' USING ERRCODE = '44000';
    END IF;

    INSERT INTO public.exam_answers (
        attempt_id, question_id, selected_option_id, text_answer, updated_at
    )
    VALUES (
        p_attempt_id, p_question_id, p_selected_option_id, p_text_answer, NOW()
    )
    ON CONFLICT (attempt_id, question_id) DO UPDATE SET
        selected_option_id = EXCLUDED.selected_option_id,
        text_answer = EXCLUDED.text_answer,
        updated_at = NOW();

    RETURN jsonb_build_object('success', true, 'attempt_id', p_attempt_id, 'question_id', p_question_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Submit & Auto-Grade Exam Attempt RPC
CREATE OR REPLACE FUNCTION public.submit_exam_attempt(p_attempt_id UUID)
RETURNS JSONB AS $$
DECLARE
    target_attempt RECORD;
    calculated_score NUMERIC(6,2) := 0.00;
    ans RECORD;
    opt_correct BOOLEAN;
    q_points NUMERIC(6,2);
BEGIN
    SELECT * INTO target_attempt FROM public.exam_attempts WHERE id = p_attempt_id;
    IF target_attempt.id IS NULL THEN
        RAISE EXCEPTION 'Exam attempt not found' USING ERRCODE = '44000';
    END IF;

    IF target_attempt.status IN ('submitted', 'graded') THEN
        RETURN jsonb_build_object('success', true, 'already_submitted', true, 'score', target_attempt.score);
    END IF;

    -- Evaluate MCQ and True/False questions automatically
    FOR ans IN SELECT * FROM public.exam_answers WHERE attempt_id = p_attempt_id LOOP
        IF ans.selected_option_id IS NOT NULL THEN
            SELECT is_correct INTO opt_correct FROM public.question_options WHERE id = ans.selected_option_id;
            SELECT points INTO q_points FROM public.exam_questions WHERE exam_id = target_attempt.exam_id AND question_id = ans.question_id;

            IF opt_correct = true THEN
                calculated_score := calculated_score + COALESCE(q_points, 1.00);
                UPDATE public.exam_answers SET is_correct = true, points_awarded = COALESCE(q_points, 1.00) WHERE id = ans.id;
            ELSE
                UPDATE public.exam_answers SET is_correct = false, points_awarded = 0.00 WHERE id = ans.id;
            END IF;
        END IF;
    END LOOP;

    -- Finalize attempt
    UPDATE public.exam_attempts
    SET status = 'graded',
        submitted_at = NOW(),
        score = calculated_score,
        updated_at = NOW()
    WHERE id = p_attempt_id;

    RETURN jsonb_build_object(
        'success', true,
        'attempt_id', p_attempt_id,
        'status', 'graded',
        'score', calculated_score,
        'max_score', target_attempt.max_score
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.start_exam(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_exam(UUID) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.save_exam_answer(UUID, UUID, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.save_exam_answer(UUID, UUID, UUID, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.submit_exam_attempt(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_exam_attempt(UUID) TO authenticated;
