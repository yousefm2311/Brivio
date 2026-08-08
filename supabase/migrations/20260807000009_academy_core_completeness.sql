-- Migration: 20260807000009_academy_core_completeness.sql
-- Description: Academy Core Completeness (Atomic Primary Guardian Transition, Server-Side Pagination RPCs)

-- 1. Atomic Primary Guardian Management RPC Function
CREATE OR REPLACE FUNCTION public.set_primary_guardian(
    p_student_id UUID,
    p_parent_id UUID,
    p_relationship_type TEXT DEFAULT 'guardian'
)
RETURNS JSONB AS $$
BEGIN
    -- Authorize caller
    IF NOT (public.is_admin_or_super() OR public.has_permission('parents.view')) THEN
        RAISE EXCEPTION 'Unauthorized to manage parent links' USING ERRCODE = '42501';
    END IF;

    -- Step A: Demote existing primary guardians for this student
    UPDATE public.parent_students
    SET is_primary = false
    WHERE student_id = p_student_id AND is_primary = true;

    -- Step B: Upsert target parent-student link as primary
    INSERT INTO public.parent_students (parent_id, student_id, relationship_type, is_primary, created_at)
    VALUES (p_parent_id, p_student_id, p_relationship_type, true, NOW())
    ON CONFLICT (parent_id, student_id) DO UPDATE SET
        is_primary = true,
        relationship_type = EXCLUDED.relationship_type;

    RETURN jsonb_build_object(
        'success', true,
        'student_id', p_student_id,
        'primary_parent_id', p_parent_id,
        'message', 'Primary guardian set successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.set_primary_guardian(UUID, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_primary_guardian(UUID, UUID, TEXT) TO authenticated;

-- 2. Server-Side Paginated Student Query RPC
CREATE OR REPLACE FUNCTION public.get_student_list(
    p_search TEXT DEFAULT NULL,
    p_branch_id UUID DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20
)
RETURNS JSONB AS $$
DECLARE
    offset_val INT;
    total_count INT;
    items JSONB;
BEGIN
    offset_val := (GREATEST(1, p_page) - 1) * GREATEST(1, p_page_size);

    SELECT COUNT(*)::int INTO total_count
    FROM public.students s
    JOIN public.profiles p ON p.id = s.profile_id
    WHERE (p_branch_id IS NULL OR s.primary_branch_id = p_branch_id)
      AND (p_status IS NULL OR s.status = p_status)
      AND (p_search IS NULL OR TRIM(p_search) = '' OR (
          p.full_name ILIKE '%' || p_search || '%' OR
          s.student_code ILIKE '%' || p_search || '%' OR
          p.email ILIKE '%' || p_search || '%'
      ));

    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO items
    FROM (
        SELECT
            s.id,
            s.profile_id,
            s.student_code,
            s.primary_branch_id,
            s.grade_level,
            s.school_name,
            s.status,
            s.created_at,
            p.full_name,
            p.email,
            p.avatar_url,
            p.phone_number
        FROM public.students s
        JOIN public.profiles p ON p.id = s.profile_id
        WHERE (p_branch_id IS NULL OR s.primary_branch_id = p_branch_id)
          AND (p_status IS NULL OR s.status = p_status)
          AND (p_search IS NULL OR TRIM(p_search) = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              s.student_code ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%'
          ))
        ORDER BY p.full_name ASC
        LIMIT p_page_size OFFSET offset_val
    ) item;

    RETURN jsonb_build_object(
        'total', total_count,
        'page', p_page,
        'page_size', p_page_size,
        'data', items
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.get_student_list(TEXT, UUID, TEXT, INT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_student_list(TEXT, UUID, TEXT, INT, INT) TO authenticated;

-- 3. Server-Side Paginated Parent Query RPC
CREATE OR REPLACE FUNCTION public.get_parent_list(
    p_search TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20
)
RETURNS JSONB AS $$
DECLARE
    offset_val INT;
    total_count INT;
    items JSONB;
BEGIN
    offset_val := (GREATEST(1, p_page) - 1) * GREATEST(1, p_page_size);

    SELECT COUNT(*)::int INTO total_count
    FROM public.parents pr
    JOIN public.profiles p ON p.id = pr.profile_id
    WHERE (p_search IS NULL OR TRIM(p_search) = '' OR (
        p.full_name ILIKE '%' || p_search || '%' OR
        p.email ILIKE '%' || p_search || '%' OR
        p.phone_number ILIKE '%' || p_search || '%'
    ));

    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO items
    FROM (
        SELECT
            pr.id,
            pr.profile_id,
            pr.occupation,
            pr.status,
            pr.created_at,
            p.full_name,
            p.email,
            p.avatar_url,
            p.phone_number
        FROM public.parents pr
        JOIN public.profiles p ON p.id = pr.profile_id
        WHERE (p_search IS NULL OR TRIM(p_search) = '' OR (
            p.full_name ILIKE '%' || p_search || '%' OR
            p.email ILIKE '%' || p_search || '%' OR
            p.phone_number ILIKE '%' || p_search || '%'
        ))
        ORDER BY p.full_name ASC
        LIMIT p_page_size OFFSET offset_val
    ) item;

    RETURN jsonb_build_object(
        'total', total_count,
        'page', p_page,
        'page_size', p_page_size,
        'data', items
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.get_parent_list(TEXT, INT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_parent_list(TEXT, INT, INT) TO authenticated;

-- 4. Server-Side Paginated Teacher Query RPC
CREATE OR REPLACE FUNCTION public.get_teacher_list(
    p_search TEXT DEFAULT NULL,
    p_branch_id UUID DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20
)
RETURNS JSONB AS $$
DECLARE
    offset_val INT;
    total_count INT;
    items JSONB;
BEGIN
    offset_val := (GREATEST(1, p_page) - 1) * GREATEST(1, p_page_size);

    SELECT COUNT(*)::int INTO total_count
    FROM public.teachers t
    JOIN public.profiles p ON p.id = t.profile_id
    WHERE (p_branch_id IS NULL OR t.primary_branch_id = p_branch_id)
      AND (p_search IS NULL OR TRIM(p_search) = '' OR (
          p.full_name ILIKE '%' || p_search || '%' OR
          p.email ILIKE '%' || p_search || '%' OR
          t.specialization ILIKE '%' || p_search || '%'
      ));

    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO items
    FROM (
        SELECT
            t.id,
            t.profile_id,
            t.primary_branch_id,
            t.specialization,
            t.bio,
            t.created_at,
            p.full_name,
            p.email,
            p.avatar_url,
            p.phone_number
        FROM public.teachers t
        JOIN public.profiles p ON p.id = t.profile_id
        WHERE (p_branch_id IS NULL OR t.primary_branch_id = p_branch_id)
          AND (p_search IS NULL OR TRIM(p_search) = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%' OR
              t.specialization ILIKE '%' || p_search || '%'
          ))
        ORDER BY p.full_name ASC
        LIMIT p_page_size OFFSET offset_val
    ) item;

    RETURN jsonb_build_object(
        'total', total_count,
        'page', p_page,
        'page_size', p_page_size,
        'data', items
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.get_teacher_list(TEXT, UUID, INT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_list(TEXT, UUID, INT, INT) TO authenticated;
