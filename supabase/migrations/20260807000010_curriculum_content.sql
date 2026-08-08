-- Migration: 20260807000010_curriculum_content.sql
-- Description: Curriculum & Content Engine Infrastructure (Access Verification, Atomic Progress Tracking RPC, Lesson Reordering, Storage RLS)

-- 0. Schema Additions for Curriculum Engine
ALTER TABLE public.lessons ADD COLUMN IF NOT EXISTS estimated_duration_minutes INT;

-- 1. Helper Function: Verify Student Access to Lesson via Active Subject Group Enrollment
CREATE OR REPLACE FUNCTION public.current_student_can_access_lesson(p_lesson_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    s_id UUID;
    sub_id UUID;
    has_access BOOLEAN;
BEGIN
    -- System context (auth.uid() IS NULL) or Admin/Super Admin always authorized
    IF auth.uid() IS NULL OR public.is_admin_or_super() THEN
        RETURN true;
    END IF;

    -- Resolve student ID from auth.uid()
    SELECT id INTO s_id FROM public.students WHERE profile_id = auth.uid() AND status = 'active';
    IF s_id IS NULL THEN
        RETURN false;
    END IF;

    -- Resolve subject_id for lesson
    SELECT sem.subject_id INTO sub_id
    FROM public.lessons l
    JOIN public.units u ON u.id = l.unit_id
    JOIN public.semesters sem ON sem.id = u.semester_id
    WHERE l.id = p_lesson_id;

    IF sub_id IS NULL THEN
        RETURN false;
    END IF;

    -- Check active student group enrollment in subject
    SELECT EXISTS (
        SELECT 1 FROM public.enrollments e
        JOIN public.groups g ON g.id = e.group_id
        WHERE e.student_id = s_id
          AND e.status = 'active'
          AND g.subject_id = sub_id
          AND g.status = 'active'
    ) INTO has_access;

    RETURN has_access;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.current_student_can_access_lesson(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_student_can_access_lesson(UUID) TO authenticated;

-- 2. Atomic Student Lesson Progress Update RPC
CREATE OR REPLACE FUNCTION public.update_lesson_progress(
    p_lesson_id UUID,
    p_status TEXT,
    p_progress_percentage INT DEFAULT 0,
    p_last_position_seconds INT DEFAULT 0,
    p_time_spent_seconds INT DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
    s_id UUID;
    bounded_progress INT;
    is_completed BOOLEAN;
BEGIN
    SELECT id INTO s_id FROM public.students WHERE profile_id = auth.uid();
    IF s_id IS NULL THEN
        RAISE EXCEPTION 'Only active enrolled students can update lesson progress' USING ERRCODE = '42501';
    END IF;

    IF NOT public.current_student_can_access_lesson(p_lesson_id) THEN
        RAISE EXCEPTION 'Unauthorized to access this lesson' USING ERRCODE = '42501';
    END IF;

    bounded_progress := GREATEST(0, LEAST(100, p_progress_percentage));
    is_completed := (p_status = 'completed' OR bounded_progress >= 100);

    INSERT INTO public.lesson_progress (
        student_id,
        lesson_id,
        status,
        progress_percentage,
        last_position,
        time_spent_seconds,
        completed_at,
        last_accessed_at
    )
    VALUES (
        s_id,
        p_lesson_id,
        CASE WHEN is_completed THEN 'completed' ELSE p_status END,
        bounded_progress,
        p_last_position_seconds::text,
        p_time_spent_seconds,
        CASE WHEN is_completed THEN NOW() ELSE NULL END,
        NOW()
    )
    ON CONFLICT (student_id, lesson_id) DO UPDATE SET
        status = CASE WHEN EXCLUDED.status = 'completed' OR lesson_progress.status = 'completed' THEN 'completed' ELSE EXCLUDED.status END,
        progress_percentage = GREATEST(lesson_progress.progress_percentage, EXCLUDED.progress_percentage),
        last_position = EXCLUDED.last_position,
        time_spent_seconds = lesson_progress.time_spent_seconds + EXCLUDED.time_spent_seconds,
        completed_at = COALESCE(lesson_progress.completed_at, CASE WHEN EXCLUDED.status = 'completed' THEN NOW() ELSE NULL END),
        last_accessed_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'student_id', s_id,
        'lesson_id', p_lesson_id,
        'progress_percentage', bounded_progress,
        'completed', is_completed
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.update_lesson_progress(UUID, TEXT, INT, INT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_lesson_progress(UUID, TEXT, INT, INT, INT) TO authenticated;

-- 3. Atomic Lesson Reordering RPC Function
CREATE OR REPLACE FUNCTION public.reorder_lessons(
    p_unit_id UUID,
    p_ordered_lesson_ids UUID[]
)
RETURNS JSONB AS $$
DECLARE
    i INT;
    target_id UUID;
BEGIN
    IF NOT (auth.uid() IS NULL OR public.is_admin_or_super() OR public.has_permission('curriculum.publish')) THEN
        RAISE EXCEPTION 'Unauthorized to reorder lessons' USING ERRCODE = '42501';
    END IF;

    FOR i IN 1..array_length(p_ordered_lesson_ids, 1) LOOP
        target_id := p_ordered_lesson_ids[i];
        UPDATE public.lessons
        SET order_number = i,
            updated_at = NOW()
        WHERE id = target_id AND unit_id = p_unit_id;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'unit_id', p_unit_id,
        'total_reordered', array_length(p_ordered_lesson_ids, 1)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.reorder_lessons(UUID, UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reorder_lessons(UUID, UUID[]) TO authenticated;

-- 4. Storage Bucket Configuration for Protected Educational Assets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'curriculum_assets',
    'curriculum_assets',
    false,
    104857600, -- 100 MB Limit
    ARRAY['video/mp4', 'application/pdf', 'image/png', 'image/jpeg', 'text/plain']
)
ON CONFLICT (id) DO UPDATE SET public = false;
