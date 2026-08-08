-- Migration: 20260807000011_curriculum_runtime_completion.sql
-- Description: Curriculum Runtime & Content Delivery Infrastructure (Server-Authoritative Publishing RPC, Multi-Level Reordering RPCs, Storage RLS Policies)

-- 1. Server-Authoritative Lesson Publishing RPC
CREATE OR REPLACE FUNCTION public.publish_lesson(p_lesson_id UUID)
RETURNS JSONB AS $$
DECLARE
    target_lesson RECORD;
    has_res BOOLEAN;
BEGIN
    -- Authorization check
    IF NOT (auth.uid() IS NULL OR public.is_admin_or_super() OR public.has_permission('curriculum.publish')) THEN
        RAISE EXCEPTION 'Unauthorized to publish lesson' USING ERRCODE = '42501';
    END IF;

    -- Fetch lesson details
    SELECT * INTO target_lesson FROM public.lessons WHERE id = p_lesson_id;
    IF target_lesson.id IS NULL THEN
        RAISE EXCEPTION 'Lesson not found' USING ERRCODE = '44000';
    END IF;

    -- Type-specific validation before publication
    IF target_lesson.lesson_type = 'video' THEN
        SELECT EXISTS (
            SELECT 1 FROM public.lesson_resources
            WHERE lesson_id = p_lesson_id AND resource_type = 'video'
        ) INTO has_res;
        IF NOT has_res THEN
            RAISE EXCEPTION 'Cannot publish video lesson without attached video resource' USING ERRCODE = '22000';
        END IF;
    ELSIF target_lesson.lesson_type = 'pdf' THEN
        SELECT EXISTS (
            SELECT 1 FROM public.lesson_resources
            WHERE lesson_id = p_lesson_id AND resource_type = 'pdf'
        ) INTO has_res;
        IF NOT has_res THEN
            RAISE EXCEPTION 'Cannot publish PDF lesson without attached PDF resource' USING ERRCODE = '22000';
        END IF;
    ELSIF target_lesson.lesson_type = 'text' THEN
        IF LENGTH(TRIM(target_lesson.title)) = 0 THEN
            RAISE EXCEPTION 'Cannot publish text lesson with empty title' USING ERRCODE = '22000';
        END IF;
    END IF;

    -- Execute server-side publication
    UPDATE public.lessons
    SET status = 'published',
        published_at = NOW(),
        updated_at = NOW()
    WHERE id = p_lesson_id;

    RETURN jsonb_build_object(
        'success', true,
        'lesson_id', p_lesson_id,
        'status', 'published',
        'published_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.publish_lesson(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_lesson(UUID) TO authenticated;

-- 2. Atomic Semester Reordering RPC
CREATE OR REPLACE FUNCTION public.reorder_semesters(
    p_subject_id UUID,
    p_ordered_ids UUID[]
)
RETURNS JSONB AS $$
DECLARE
    i INT;
    target_id UUID;
BEGIN
    IF NOT (auth.uid() IS NULL OR public.is_admin_or_super() OR public.has_permission('curriculum.publish')) THEN
        RAISE EXCEPTION 'Unauthorized to reorder semesters' USING ERRCODE = '42501';
    END IF;

    -- Temporary offset to prevent UNIQUE constraint collisions
    FOR i IN 1..array_length(p_ordered_ids, 1) LOOP
        target_id := p_ordered_ids[i];
        UPDATE public.semesters SET order_number = 10000 + i WHERE id = target_id AND subject_id = p_subject_id;
    END LOOP;

    -- Apply target order numbers
    FOR i IN 1..array_length(p_ordered_ids, 1) LOOP
        target_id := p_ordered_ids[i];
        UPDATE public.semesters SET order_number = i, updated_at = NOW() WHERE id = target_id AND subject_id = p_subject_id;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'subject_id', p_subject_id, 'total', array_length(p_ordered_ids, 1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Atomic Unit Reordering RPC
CREATE OR REPLACE FUNCTION public.reorder_units(
    p_semester_id UUID,
    p_ordered_ids UUID[]
)
RETURNS JSONB AS $$
DECLARE
    i INT;
    target_id UUID;
BEGIN
    IF NOT (auth.uid() IS NULL OR public.is_admin_or_super() OR public.has_permission('curriculum.publish')) THEN
        RAISE EXCEPTION 'Unauthorized to reorder units' USING ERRCODE = '42501';
    END IF;

    -- Temporary offset to prevent UNIQUE constraint collisions
    FOR i IN 1..array_length(p_ordered_ids, 1) LOOP
        target_id := p_ordered_ids[i];
        UPDATE public.units SET order_number = 10000 + i WHERE id = target_id AND semester_id = p_semester_id;
    END LOOP;

    -- Apply target order numbers
    FOR i IN 1..array_length(p_ordered_ids, 1) LOOP
        target_id := p_ordered_ids[i];
        UPDATE public.units SET order_number = i, updated_at = NOW() WHERE id = target_id AND semester_id = p_semester_id;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'semester_id', p_semester_id, 'total', array_length(p_ordered_ids, 1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Atomic Lesson Resource Reordering RPC
CREATE OR REPLACE FUNCTION public.reorder_lesson_resources(
    p_lesson_id UUID,
    p_ordered_ids UUID[]
)
RETURNS JSONB AS $$
DECLARE
    i INT;
    target_id UUID;
BEGIN
    IF NOT (auth.uid() IS NULL OR public.is_admin_or_super() OR public.has_permission('curriculum.publish')) THEN
        RAISE EXCEPTION 'Unauthorized to reorder lesson resources' USING ERRCODE = '42501';
    END IF;

    FOR i IN 1..array_length(p_ordered_ids, 1) LOOP
        target_id := p_ordered_ids[i];
        UPDATE public.lesson_resources SET order_number = i, updated_at = NOW() WHERE id = target_id AND lesson_id = p_lesson_id;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'lesson_id', p_lesson_id, 'total', array_length(p_ordered_ids, 1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 5. Storage RLS Policies for curriculum_assets Bucket
DROP POLICY IF EXISTS "Curriculum assets viewable by authorized users" ON storage.objects;
CREATE POLICY "Curriculum assets viewable by authorized users"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'curriculum_assets' AND (
        public.is_admin_or_super() OR
        public.has_permission('curriculum.view')
    )
);

DROP POLICY IF EXISTS "Curriculum assets manageable by authorized editors" ON storage.objects;
CREATE POLICY "Curriculum assets manageable by authorized editors"
ON storage.objects FOR ALL
TO authenticated
USING (
    bucket_id = 'curriculum_assets' AND (
        public.is_admin_or_super() OR
        public.has_permission('curriculum.publish')
    )
);
