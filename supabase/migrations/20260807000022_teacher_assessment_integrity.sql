-- Migration 00022: Teacher Assessment Integrity, Group Roster Security & Trusted RPC Operations

-- 1. Helper function: Check if teacher is assigned to a group's subject
CREATE OR REPLACE FUNCTION public.is_teacher_assigned_to_subject(p_teacher_user_id UUID, p_subject_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    is_assigned BOOLEAN := false;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.group_teachers gt
        JOIN public.groups g ON gt.group_id = g.id
        JOIN public.teachers t ON gt.teacher_id = t.id
        WHERE t.profile_id = p_teacher_user_id
          AND g.subject_id = p_subject_id
          AND gt.status = 'active'
    ) INTO is_assigned;

    RETURN is_assigned;
END;
$$;

-- 2. Group Roster RPC: Get enrolled students for a specific group with authorization check
CREATE OR REPLACE FUNCTION public.get_group_students(p_group_id UUID)
RETURNS TABLE (
    id UUID,
    profile_id UUID,
    student_code TEXT,
    full_name TEXT,
    email TEXT,
    status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Security Check: Admin/Super or assigned Teacher or permission holder
    IF NOT (
        public.is_admin_or_super() OR
        public.has_permission('enrollments.view') OR
        public.current_teacher_assigned_to_group(p_group_id)
    ) THEN
        RAISE EXCEPTION 'Unauthorized to view group roster' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT 
        s.id,
        s.profile_id,
        s.student_code,
        p.full_name,
        p.email,
        s.status
    FROM public.enrollments e
    JOIN public.students s ON e.student_id = s.id
    JOIN public.profiles p ON s.profile_id = p.id
    WHERE e.group_id = p_group_id
      AND e.status = 'active'
    ORDER BY p.full_name ASC;
END;
$$;

-- 3. Trusted Homework Creation RPC
CREATE OR REPLACE FUNCTION public.create_homework_assignment(
    p_title TEXT,
    p_description TEXT,
    p_subject_id UUID,
    p_group_id UUID,
    p_due_at TIMESTAMPTZ,
    p_max_score NUMERIC,
    p_status TEXT DEFAULT 'published'
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
    -- Security Check: Must be assigned teacher or admin
    IF NOT (
        public.is_admin_or_super() OR
        public.has_permission('homework.create') OR
        public.current_teacher_assigned_to_group(p_group_id)
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Teacher not assigned to target group' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.homework (
        title,
        description,
        subject_id,
        group_id,
        due_at,
        max_score,
        status,
        created_by
    ) VALUES (
        p_title,
        p_description,
        p_subject_id,
        p_group_id,
        p_due_at,
        COALESCE(p_max_score, 100.0),
        COALESCE(p_status, 'published'),
        auth.uid()
    )
    RETURNING id INTO v_homework_id;

    SELECT to_jsonb(h.*) INTO v_result
    FROM public.homework h
    WHERE h.id = v_homework_id;

    RETURN v_result;
END;
$$;

-- 4. Trusted Homework Publishing RPC
CREATE OR REPLACE FUNCTION public.publish_homework(p_homework_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_group_id UUID;
    v_result JSONB;
BEGIN
    SELECT group_id INTO v_group_id FROM public.homework WHERE id = p_homework_id;
    IF v_group_id IS NULL THEN
        RAISE EXCEPTION 'Homework not found' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        public.is_admin_or_super() OR
        public.current_teacher_assigned_to_group(v_group_id)
    ) THEN
        RAISE EXCEPTION 'Unauthorized to publish homework' USING ERRCODE = '42501';
    END IF;

    UPDATE public.homework
    SET status = 'published',
        updated_at = NOW()
    WHERE id = p_homework_id;

    SELECT to_jsonb(h.*) INTO v_result
    FROM public.homework h
    WHERE h.id = p_homework_id;

    RETURN v_result;
END;
$$;

-- 5. Trusted Homework Grading RPC with Score Bounds Enforcement
CREATE OR REPLACE FUNCTION public.grade_homework_submission(
    p_submission_id UUID,
    p_score NUMERIC,
    p_feedback TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_homework_id UUID;
    v_group_id UUID;
    v_max_score NUMERIC;
    v_result JSONB;
BEGIN
    SELECT s.homework_id, h.group_id, h.max_score
    INTO v_homework_id, v_group_id, v_max_score
    FROM public.homework_submissions s
    JOIN public.homework h ON s.homework_id = h.id
    WHERE s.id = p_submission_id;

    IF v_homework_id IS NULL THEN
        RAISE EXCEPTION 'Submission not found' USING ERRCODE = '22023';
    END IF;

    -- Security Check: Must be assigned teacher or admin or have homework.grade
    IF NOT (
        public.is_admin_or_super() OR
        public.has_permission('homework.grade') OR
        public.current_teacher_assigned_to_group(v_group_id)
    ) THEN
        RAISE EXCEPTION 'Unauthorized to grade homework submission' USING ERRCODE = '42501';
    END IF;

    -- Score Bounds Check
    IF p_score < 0 OR p_score > v_max_score THEN
        RAISE EXCEPTION 'Score out of bounds (Must be between 0 and %)', v_max_score USING ERRCODE = '22003';
    END IF;

    -- Update grading fields only without touching student answer text
    UPDATE public.homework_submissions
    SET score = p_score,
        teacher_feedback = p_feedback,
        status = 'graded',
        graded_at = NOW(),
        graded_by = auth.uid()
    WHERE id = p_submission_id;

    SELECT to_jsonb(s.*) INTO v_result
    FROM public.homework_submissions s
    WHERE s.id = p_submission_id;

    RETURN v_result;
END;
$$;

-- 6. Trusted Exam Creation RPC
CREATE OR REPLACE FUNCTION public.create_exam_assignment(
    p_title TEXT,
    p_subject_id UUID,
    p_group_id UUID,
    p_duration_minutes INT,
    p_pass_score NUMERIC,
    p_max_score NUMERIC,
    p_status TEXT DEFAULT 'published'
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
    IF NOT (
        public.is_admin_or_super() OR
        public.has_permission('exams.create') OR
        public.current_teacher_assigned_to_group(p_group_id)
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Teacher not assigned to target group' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.exams (
        title,
        subject_id,
        group_id,
        duration_minutes,
        pass_score,
        max_score,
        status,
        published_at,
        created_by
    ) VALUES (
        p_title,
        p_subject_id,
        p_group_id,
        COALESCE(p_duration_minutes, 60),
        COALESCE(p_pass_score, 60.0),
        COALESCE(p_max_score, 100.0),
        COALESCE(p_status, 'published'),
        CASE WHEN COALESCE(p_status, 'published') = 'published' THEN NOW() ELSE NULL END,
        auth.uid()
    )
    RETURNING id INTO v_exam_id;

    SELECT to_jsonb(e.*) INTO v_result
    FROM public.exams e
    WHERE e.id = v_exam_id;

    RETURN v_result;
END;
$$;

-- Grant EXECUTE permissions
GRANT EXECUTE ON FUNCTION public.is_teacher_assigned_to_subject(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_group_students(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_homework_assignment(TEXT, TEXT, UUID, UUID, TIMESTAMPTZ, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_homework(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grade_homework_submission(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_exam_assignment(TEXT, UUID, UUID, INT, NUMERIC, NUMERIC, TEXT) TO authenticated;
