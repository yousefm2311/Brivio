-- QR attendance runtime: rotating teacher QR tokens and student scan validation.

CREATE TABLE IF NOT EXISTS public.attendance_qr_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_session_id UUID NOT NULL REFERENCES public.class_sessions(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  bucket_minute BIGINT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'closed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.attendance_records
  ADD COLUMN IF NOT EXISTS check_in_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS device_id TEXT,
  ADD COLUMN IF NOT EXISTS latitude NUMERIC,
  ADD COLUMN IF NOT EXISTS longitude NUMERIC,
  ADD COLUMN IF NOT EXISTS qr_session_id UUID REFERENCES public.attendance_qr_sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_attendance_qr_sessions_token
  ON public.attendance_qr_sessions(token);
CREATE INDEX IF NOT EXISTS idx_attendance_qr_sessions_class_session
  ON public.attendance_qr_sessions(class_session_id, status, expires_at);
CREATE INDEX IF NOT EXISTS idx_attendance_records_qr_session
  ON public.attendance_records(qr_session_id);

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'curriculum_assets',
  'curriculum_assets',
  false,
  52428800,
  ARRAY['application/pdf', 'video/mp4', 'image/png', 'image/jpeg']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Curriculum assets readable by lesson access" ON storage.objects;
CREATE POLICY "Curriculum assets readable by lesson access"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'curriculum_assets'
  AND (
    public.is_admin_or_super()
    OR public.has_permission('curriculum.view')
    OR public.current_user_role() IN ('teacher', 'staff')
    OR EXISTS (
      SELECT 1
      FROM public.lesson_resources lr
      WHERE lr.bucket = bucket_id
        AND lr.object_path = name
        AND public.current_student_can_access_lesson(lr.lesson_id)
    )
  )
);

DROP POLICY IF EXISTS "Curriculum assets writable by educators" ON storage.objects;
CREATE POLICY "Curriculum assets writable by educators"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'curriculum_assets'
  AND (
    public.is_admin_or_super()
    OR public.has_permission('curriculum.publish')
    OR public.current_user_role() IN ('teacher', 'staff')
  )
);

DROP POLICY IF EXISTS "Curriculum assets updatable by educators" ON storage.objects;
CREATE POLICY "Curriculum assets updatable by educators"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'curriculum_assets'
  AND (
    public.is_admin_or_super()
    OR public.has_permission('curriculum.publish')
    OR public.current_user_role() IN ('teacher', 'staff')
  )
)
WITH CHECK (
  bucket_id = 'curriculum_assets'
  AND (
    public.is_admin_or_super()
    OR public.has_permission('curriculum.publish')
    OR public.current_user_role() IN ('teacher', 'staff')
  )
);

ALTER TABLE public.attendance_qr_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Attendance QR sessions viewable by assigned teacher or admins"
ON public.attendance_qr_sessions;
CREATE POLICY "Attendance QR sessions viewable by assigned teacher or admins"
ON public.attendance_qr_sessions FOR SELECT TO authenticated
USING (
  public.is_admin_or_super()
  OR teacher_id = public.current_teacher_id()
);

DROP FUNCTION IF EXISTS public.get_current_attendance_qr(UUID);
CREATE OR REPLACE FUNCTION public.get_current_attendance_qr(p_class_session_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cs RECORD;
  v_teacher_id UUID := public.current_teacher_id();
  v_bucket BIGINT := FLOOR(EXTRACT(EPOCH FROM NOW()) / 60);
  v_qr RECORD;
  v_token TEXT;
BEGIN
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Teacher profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO cs FROM public.class_sessions WHERE id = p_class_session_id;
  IF cs.id IS NULL THEN
    RAISE EXCEPTION 'Class session not found' USING ERRCODE = 'P0002';
  END IF;

  IF cs.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'Class session is closed for attendance QR'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.current_teacher_assigned_to_group(cs.group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to create attendance QR for this session'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.attendance_qr_sessions
  SET status = 'expired', updated_at = NOW()
  WHERE class_session_id = p_class_session_id
    AND status = 'active'
    AND (expires_at <= NOW() OR bucket_minute <> v_bucket);

  SELECT * INTO v_qr
  FROM public.attendance_qr_sessions
  WHERE class_session_id = p_class_session_id
    AND teacher_id = v_teacher_id
    AND bucket_minute = v_bucket
    AND status = 'active'
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_qr.id IS NULL THEN
    v_token := replace(gen_random_uuid()::TEXT, '-', '') || replace(gen_random_uuid()::TEXT, '-', '');
    INSERT INTO public.attendance_qr_sessions (
      class_session_id,
      group_id,
      teacher_id,
      token,
      bucket_minute,
      expires_at,
      status
    ) VALUES (
      p_class_session_id,
      cs.group_id,
      v_teacher_id,
      v_token,
      v_bucket,
      NOW() + INTERVAL '75 seconds',
      'active'
    )
    RETURNING * INTO v_qr;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'token', v_qr.token,
    'expires_at', v_qr.expires_at,
    'class_session_id', v_qr.class_session_id,
    'group_id', v_qr.group_id,
    'ttl_seconds', GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (v_qr.expires_at - NOW()))))::INT
  );
END;
$$;

DROP FUNCTION IF EXISTS public.validate_attendance_qr(TEXT, TEXT, NUMERIC, NUMERIC);
CREATE OR REPLACE FUNCTION public.validate_attendance_qr(
  p_token TEXT,
  p_device_id TEXT DEFAULT NULL,
  p_latitude NUMERIC DEFAULT NULL,
  p_longitude NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
  v_qr RECORD;
  v_record_id UUID;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_qr
  FROM public.attendance_qr_sessions
  WHERE token = trim(COALESCE(p_token, ''))
    AND status = 'active'
    AND expires_at > NOW()
  LIMIT 1;

  IF v_qr.id IS NULL THEN
    RAISE EXCEPTION 'Attendance QR has expired or is invalid' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.enrollments
    WHERE student_id = v_student_id
      AND group_id = v_qr.group_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Student is not enrolled in this session group' USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.attendance_records ar
    WHERE ar.class_session_id = v_qr.class_session_id
      AND ar.student_id = v_student_id
      AND ar.device_id IS NOT NULL
      AND NULLIF(trim(COALESCE(p_device_id, '')), '') IS NOT NULL
      AND ar.device_id <> NULLIF(trim(COALESCE(p_device_id, '')), '')
  ) THEN
    RAISE EXCEPTION 'Attendance already marked from another device'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.attendance_records (
    class_session_id,
    student_id,
    attendance_status,
    marked_by,
    marked_at,
    check_in_at,
    device_id,
    latitude,
    longitude,
    qr_session_id,
    notes
  ) VALUES (
    v_qr.class_session_id,
    v_student_id,
    'present',
    NULL,
    NOW(),
    NOW(),
    NULLIF(trim(COALESCE(p_device_id, '')), ''),
    p_latitude,
    p_longitude,
    v_qr.id,
    'Marked present by rotating QR scan'
  )
  ON CONFLICT (class_session_id, student_id) DO UPDATE SET
    attendance_status = CASE
      WHEN attendance_records.attendance_status = 'excused' THEN 'excused'
      ELSE 'present'
    END,
    marked_at = NOW(),
    check_in_at = COALESCE(attendance_records.check_in_at, NOW()),
    device_id = COALESCE(attendance_records.device_id, EXCLUDED.device_id),
    latitude = COALESCE(attendance_records.latitude, EXCLUDED.latitude),
    longitude = COALESCE(attendance_records.longitude, EXCLUDED.longitude),
    qr_session_id = COALESCE(attendance_records.qr_session_id, EXCLUDED.qr_session_id),
    notes = EXCLUDED.notes,
    updated_at = NOW()
  RETURNING id INTO v_record_id;

  RETURN jsonb_build_object(
    'success', true,
    'attendance_record_id', v_record_id,
    'class_session_id', v_qr.class_session_id,
    'status', 'present'
  );
END;
$$;

DROP FUNCTION IF EXISTS public.get_session_qr_attendance_roster(UUID);
CREATE OR REPLACE FUNCTION public.get_session_qr_attendance_roster(
  p_class_session_id UUID
)
RETURNS TABLE (
  student_id UUID,
  student_code TEXT,
  full_name TEXT,
  attendance_status TEXT,
  check_in_at TIMESTAMPTZ,
  device_id TEXT,
  latitude NUMERIC,
  longitude NUMERIC,
  marked_by_qr BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cs RECORD;
BEGIN
  SELECT * INTO cs FROM public.class_sessions WHERE id = p_class_session_id;
  IF cs.id IS NULL THEN
    RAISE EXCEPTION 'Class session not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('attendance.view')
    OR public.current_teacher_assigned_to_group(cs.group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view attendance roster'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    s.id AS student_id,
    COALESCE(s.student_code, '')::TEXT AS student_code,
    COALESCE(p.full_name, s.student_code, 'Student')::TEXT AS full_name,
    COALESCE(ar.attendance_status, 'pending')::TEXT AS attendance_status,
    ar.check_in_at,
    ar.device_id,
    ar.latitude,
    ar.longitude,
    (ar.qr_session_id IS NOT NULL)::BOOLEAN AS marked_by_qr
  FROM public.enrollments e
  JOIN public.students s ON s.id = e.student_id
  LEFT JOIN public.profiles p ON p.id = s.profile_id
  LEFT JOIN public.attendance_records ar
    ON ar.student_id = s.id
   AND ar.class_session_id = p_class_session_id
  WHERE e.group_id = cs.group_id
    AND e.status = 'active'
  ORDER BY COALESCE(p.full_name, s.student_code, s.id::TEXT);
END;
$$;

DROP FUNCTION IF EXISTS public.finalize_qr_attendance(UUID);
CREATE OR REPLACE FUNCTION public.finalize_qr_attendance(
  p_class_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cs RECORD;
  enr RECORD;
  absent_count INT := 0;
  present_count INT := 0;
  late_count INT := 0;
  total_count INT := 0;
BEGIN
  SELECT * INTO cs FROM public.class_sessions WHERE id = p_class_session_id;
  IF cs.id IS NULL THEN
    RAISE EXCEPTION 'Class session not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('attendance.finalize')
    OR public.current_teacher_assigned_to_group(cs.group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to finalize QR attendance'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.attendance_qr_sessions
  SET status = 'closed', updated_at = NOW()
  WHERE class_session_id = p_class_session_id
    AND status = 'active';

  FOR enr IN
    SELECT student_id
    FROM public.enrollments
    WHERE group_id = cs.group_id
      AND status = 'active'
  LOOP
    total_count := total_count + 1;
    IF NOT EXISTS (
      SELECT 1
      FROM public.attendance_records
      WHERE class_session_id = p_class_session_id
        AND student_id = enr.student_id
    ) THEN
      INSERT INTO public.attendance_records (
        class_session_id,
        student_id,
        attendance_status,
        marked_by,
        marked_at,
        notes
      ) VALUES (
        p_class_session_id,
        enr.student_id,
        'absent',
        auth.uid(),
        NOW(),
        'Auto-marked absent on QR attendance finalization'
      );
      absent_count := absent_count + 1;
    END IF;
  END LOOP;

  SELECT
    COALESCE(SUM(CASE WHEN attendance_status = 'present' THEN 1 ELSE 0 END), 0)::INT,
    COALESCE(SUM(CASE WHEN attendance_status = 'late' THEN 1 ELSE 0 END), 0)::INT,
    COALESCE(SUM(CASE WHEN attendance_status = 'absent' THEN 1 ELSE 0 END), 0)::INT
  INTO present_count, late_count, absent_count
  FROM public.attendance_records
  WHERE class_session_id = p_class_session_id;

  UPDATE public.class_sessions
  SET status = 'completed', updated_at = NOW()
  WHERE id = p_class_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'class_session_id', p_class_session_id,
    'total_count', total_count,
    'present_count', present_count,
    'late_count', late_count,
    'absent_count', absent_count,
    'status', 'completed'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_current_attendance_qr(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.validate_attendance_qr(TEXT, TEXT, NUMERIC, NUMERIC) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_session_qr_attendance_roster(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.finalize_qr_attendance(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_attendance_qr(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_attendance_qr(TEXT, TEXT, NUMERIC, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_session_qr_attendance_roster(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_qr_attendance(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
