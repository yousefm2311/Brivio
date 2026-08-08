-- Migration: 20260807000006_auth_authorization_integration.sql
-- Description: Production Auth Bootstrap, Effective Permission Evaluation, and Privileged Provisioning Infrastructure

-- 0. Account Status Column on Profiles
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

-- 1. Helper Function: Get Effective Permissions Array for User
CREATE OR REPLACE FUNCTION public.get_user_effective_permissions(target_user_id UUID)
RETURNS TEXT[] AS $$
DECLARE
    u_role text;
    perms TEXT[] := '{}';
BEGIN
    IF target_user_id IS NULL THEN
        RETURN perms;
    END IF;

    -- Check user role
    SELECT role::text INTO u_role FROM public.profiles WHERE id = target_user_id;

    IF u_role IS NULL THEN
        RETURN perms;
    END IF;

    -- If super_admin, return all available permission codes
    IF u_role = 'super_admin' THEN
        SELECT ARRAY_AGG(code) INTO perms FROM public.permissions;
        RETURN perms;
    END IF;

    -- Calculate effective permissions based on precedence:
    -- User Explicit DENY overrides ALL.
    -- Include User Explicit GRANT + Role Permissions, excluding Explicit DENY.
    SELECT ARRAY_AGG(DISTINCT code) INTO perms
    FROM (
        -- User Explicit Grants
        SELECT p.code
        FROM public.user_permissions up
        JOIN public.permissions p ON p.id = up.permission_id
        WHERE up.user_id = target_user_id AND up.effect = 'grant'

        UNION

        -- Role Baseline Permissions
        SELECT p.code
        FROM public.role_permissions rp
        JOIN public.roles r ON r.id = rp.role_id
        JOIN public.permissions p ON p.id = rp.permission_id
        WHERE r.name = u_role
    ) active_perms
    WHERE code NOT IN (
        -- User Explicit Denies
        SELECT p.code
        FROM public.user_permissions up
        JOIN public.permissions p ON p.id = up.permission_id
        WHERE up.user_id = target_user_id AND up.effect = 'deny'
    );

    RETURN COALESCE(perms, '{}');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.get_user_effective_permissions(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_effective_permissions(UUID) TO authenticated;

-- 2. Current User Bootstrap Contract (Race-Free Single Call for Application Startup)
CREATE OR REPLACE FUNCTION public.get_current_user_bootstrap()
RETURNS JSONB AS $$
DECLARE
    u_id UUID := auth.uid();
    user_prof RECORD;
    eff_perms TEXT[];
    s_id UUID;
    p_id UUID;
    t_id UUID;
    result JSONB;
BEGIN
    IF u_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated caller' USING ERRCODE = '42501';
    END IF;

    SELECT id, email, full_name, avatar_url, phone_number, role, branch_id, status, created_at, updated_at
    INTO user_prof
    FROM public.profiles
    WHERE id = u_id;

    IF user_prof IS NULL THEN
        RAISE EXCEPTION 'Profile missing for authenticated user' USING ERRCODE = 'P0002';
    END IF;

    -- Fetch effective permissions
    eff_perms := public.get_user_effective_permissions(u_id);

    -- Fetch domain entity IDs
    SELECT id INTO s_id FROM public.students WHERE profile_id = u_id;
    SELECT id INTO p_id FROM public.parents WHERE profile_id = u_id;
    SELECT id INTO t_id FROM public.teachers WHERE profile_id = u_id;

    -- Build JSON contract
    result := jsonb_build_object(
        'profile', jsonb_build_object(
            'id', user_prof.id,
            'email', user_prof.email,
            'full_name', user_prof.full_name,
            'avatar_url', user_prof.avatar_url,
            'phone_number', user_prof.phone_number,
            'role', user_prof.role,
            'branch_id', user_prof.branch_id,
            'status', user_prof.status,
            'created_at', user_prof.created_at,
            'updated_at', user_prof.updated_at
        ),
        'canonical_role', user_prof.role,
        'primary_branch_id', user_prof.branch_id,
        'account_status', user_prof.status,
        'effective_permissions', to_jsonb(eff_perms),
        'domain_identity', jsonb_build_object(
            'student_id', s_id,
            'parent_id', p_id,
            'teacher_id', t_id
        )
    );

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.get_current_user_bootstrap() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_bootstrap() TO authenticated;

-- 3. Privileged Account Provisioning Procedure
-- Super Admin can provision Admin, Staff, Teacher.
-- Admin can provision Staff, Teacher.
-- Student/Parent/Teacher/Staff CANNOT provision privileged users.
CREATE OR REPLACE FUNCTION public.provision_privileged_user(
    p_email TEXT,
    p_full_name TEXT,
    p_role user_role,
    p_branch_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    caller_role text;
    new_user_id UUID;
BEGIN
    caller_role := public.current_user_role();

    IF caller_role IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated caller' USING ERRCODE = '42501';
    END IF;

    -- Validate role permissions
    IF p_role IN ('super_admin', 'admin') AND caller_role != 'super_admin' THEN
        RAISE EXCEPTION 'Unauthorized to provision admin role' USING ERRCODE = '42501';
    END IF;

    IF p_role IN ('staff', 'teacher') AND caller_role NOT IN ('super_admin', 'admin') THEN
        RAISE EXCEPTION 'Unauthorized to provision staff/teacher role' USING ERRCODE = '42501';
    END IF;

    IF p_role IN ('student', 'parent') THEN
        RAISE EXCEPTION 'Use public signup flow for student accounts' USING ERRCODE = '22023';
    END IF;

    -- Create synthetic auth user entry for provisioning in trusted server context
    new_user_id := gen_random_uuid();

    INSERT INTO auth.users (id, instance_id, email, role, aud, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    VALUES (
        new_user_id,
        '00000000-0000-0000-0000-000000000000',
        p_email,
        'authenticated',
        'authenticated',
        jsonb_build_object('provider', 'email', 'providers', array['email']),
        jsonb_build_object('full_name', p_full_name, 'role', p_role::text),
        NOW(),
        NOW()
    );

    -- Update automatically created profile with exact target role and branch
    UPDATE public.profiles
    SET role = p_role,
        full_name = p_full_name,
        branch_id = p_branch_id,
        status = 'active'
    WHERE id = new_user_id;

    -- Auto-create domain record for teachers
    IF p_role = 'teacher' THEN
        INSERT INTO public.teachers (profile_id, primary_branch_id)
        VALUES (new_user_id, p_branch_id)
        ON CONFLICT (profile_id) DO NOTHING;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', new_user_id,
        'email', p_email,
        'role', p_role,
        'message', 'User provisioned successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.provision_privileged_user(TEXT, TEXT, user_role, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.provision_privileged_user(TEXT, TEXT, user_role, UUID) TO authenticated;
