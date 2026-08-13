-- Migration: 20260813090600_staff_admin_qr_login.sql
-- Description: Allow staff/admin accounts to use the same temporary QR password setup flow.

CREATE OR REPLACE FUNCTION public.create_account_login_qr(p_profile_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_profile RECORD;
  v_token TEXT;
  v_token_hash TEXT;
  v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '48 hours';
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('users.manage')
    OR public.current_user_role() = 'staff'
  ) THEN
    RAISE EXCEPTION 'Unauthorized to create account QR login token'
      USING ERRCODE = '42501';
  END IF;

  SELECT id, email, full_name, role INTO v_profile
  FROM public.profiles
  WHERE id = p_profile_id
    AND role IN ('student', 'parent', 'teacher', 'staff', 'admin');

  IF v_profile.id IS NULL THEN
    RAISE EXCEPTION 'Profile not found or unsupported role'
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.account_login_qr_tokens
  SET status = 'revoked'
  WHERE profile_id = p_profile_id
    AND status = 'active';

  v_token := 'acctqr_' || encode(gen_random_bytes(32), 'hex');
  v_token_hash := encode(digest(v_token, 'sha256'), 'hex');

  INSERT INTO public.account_login_qr_tokens (
    profile_id,
    token_hash,
    expires_at,
    created_by
  )
  VALUES (
    p_profile_id,
    v_token_hash,
    v_expires_at,
    auth.uid()
  );

  RETURN jsonb_build_object(
    'success', true,
    'token', v_token,
    'payload', jsonb_build_object('type', 'account_login_qr', 'token', v_token),
    'expires_at', v_expires_at,
    'profile_id', v_profile.id,
    'email', v_profile.email,
    'full_name', v_profile.full_name,
    'role', v_profile.role
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_account_login_qr(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_token_hash TEXT;
  v_record RECORD;
BEGIN
  IF COALESCE(NULLIF(TRIM(p_token), ''), '') = '' THEN
    RAISE EXCEPTION 'QR token is required' USING ERRCODE = '22023';
  END IF;

  v_token_hash := encode(digest(TRIM(p_token), 'sha256'), 'hex');

  SELECT
    t.id,
    t.expires_at,
    p.id AS profile_id,
    p.email,
    p.full_name,
    p.role
  INTO v_record
  FROM public.account_login_qr_tokens t
  JOIN public.profiles p ON p.id = t.profile_id
  WHERE t.token_hash = v_token_hash
    AND t.status = 'active'
    AND t.expires_at > NOW()
    AND p.role IN ('student', 'parent', 'teacher', 'staff', 'admin');

  IF v_record.id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired QR token' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.account_login_qr_tokens
  SET last_scanned_at = NOW(),
      scan_count = scan_count + 1
  WHERE id = v_record.id;

  RETURN jsonb_build_object(
    'success', true,
    'email', v_record.email,
    'full_name', v_record.full_name,
    'role', v_record.role,
    'profile_id', v_record.profile_id,
    'expires_at', v_record.expires_at
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_account_login_qr(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.resolve_account_login_qr(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_account_login_qr(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_account_login_qr(TEXT) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
