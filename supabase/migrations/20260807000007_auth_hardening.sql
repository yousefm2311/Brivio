-- Migration: 20260807000007_auth_hardening.sql
-- Description: Production Auth Hardening (Removal of Direct auth.users SQL Insert & Trusted Server RPC Contract)

-- 1. Drop Legacy SQL Direct auth.users Insert Function
DROP FUNCTION IF EXISTS public.provision_privileged_user(TEXT, TEXT, user_role, UUID);

-- 2. Create Trusted ServerRPC Contract for Profile & Domain Record Completion
-- Called by the authenticated Supabase Edge Function using Admin credentials
-- after the Supabase Auth Admin API creates the Auth user.
CREATE OR REPLACE FUNCTION public.complete_privileged_user_profile(
    p_target_user_id UUID,
    p_full_name TEXT,
    p_role user_role,
    p_branch_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    caller_role text;
BEGIN
    -- Determine caller role (service_role or authenticated admin)
    caller_role := public.current_user_role();

    -- Authorize caller
    IF caller_role IS NULL AND current_setting('role', true) != 'service_role' THEN
        RAISE EXCEPTION 'Unauthenticated caller' USING ERRCODE = '42501';
    END IF;

    IF caller_role IS NOT NULL AND caller_role NOT IN ('super_admin', 'admin') AND current_setting('role', true) != 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized to complete privileged profile' USING ERRCODE = '42501';
    END IF;

    IF p_role IN ('student', 'parent') THEN
        RAISE EXCEPTION 'Use public signup flow for student/parent accounts' USING ERRCODE = '22023';
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

    -- Auto-create domain record for teachers
    IF p_role = 'teacher' THEN
        INSERT INTO public.teachers (profile_id, primary_branch_id)
        VALUES (p_target_user_id, p_branch_id)
        ON CONFLICT (profile_id) DO NOTHING;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_target_user_id,
        'role', p_role,
        'message', 'Privileged profile and domain setup completed successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.complete_privileged_user_profile(UUID, TEXT, user_role, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_privileged_user_profile(UUID, TEXT, user_role, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_privileged_user_profile(UUID, TEXT, user_role, UUID) TO service_role;
