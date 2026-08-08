-- Migration: 20260807000021_admin_provisioning_support.sql
-- Description: Enable Admin Provisioning of Student & Parent accounts via complete_privileged_user_profile RPC

CREATE OR REPLACE FUNCTION public.complete_privileged_user_profile(
    p_target_user_id UUID,
    p_full_name TEXT,
    p_role user_role,
    p_branch_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    caller_role text;
    generated_code text;
BEGIN
    caller_role := public.current_user_role();

    -- Authorize caller
    IF caller_role IS NULL AND current_setting('role', true) != 'service_role' THEN
        RAISE EXCEPTION 'Unauthenticated caller' USING ERRCODE = '42501';
    END IF;

    IF caller_role IS NOT NULL AND caller_role NOT IN ('super_admin', 'admin') AND current_setting('role', true) != 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized to complete privileged profile' USING ERRCODE = '42501';
    END IF;

    -- Ensure profile exists
    INSERT INTO public.profiles (id, email, full_name, role, branch_id, status, created_at, updated_at)
    SELECT
        p_target_user_id,
        u.email,
        p_full_name,
        p_role,
        p_branch_id,
        'active',
        NOW(),
        NOW()
    FROM auth.users u
    WHERE u.id = p_target_user_id
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        branch_id = EXCLUDED.branch_id,
        status = 'active',
        updated_at = NOW();

    -- Auto-create domain record for teachers, students, parents
    IF p_role = 'teacher' THEN
        INSERT INTO public.teachers (profile_id, primary_branch_id)
        VALUES (p_target_user_id, p_branch_id)
        ON CONFLICT (profile_id) DO NOTHING;
    ELSIF p_role = 'student' THEN
        generated_code := 'STU-' || UPPER(SUBSTRING(p_target_user_id::text FROM 1 FOR 8));
        INSERT INTO public.students (profile_id, student_code, primary_branch_id)
        VALUES (p_target_user_id, generated_code, p_branch_id)
        ON CONFLICT (profile_id) DO NOTHING;
    ELSIF p_role = 'parent' THEN
        INSERT INTO public.parents (profile_id)
        VALUES (p_target_user_id)
        ON CONFLICT (profile_id) DO NOTHING;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_target_user_id,
        'role', p_role,
        'message', 'User profile and domain setup completed successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
