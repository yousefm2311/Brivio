-- Teacher portal core fixes: group CRUD, schedule mappings, and curriculum edits.

CREATE OR REPLACE FUNCTION public.get_teacher_assigned_groups(p_teacher_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  code TEXT,
  subject_id UUID,
  branch_id UUID,
  max_capacity INT,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('groups.view')
    OR p_teacher_id = public.current_teacher_id()
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view teacher groups' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT DISTINCT
    g.id,
    COALESCE(g.name, 'Group')::TEXT,
    COALESCE(g.code, '')::TEXT,
    g.subject_id,
    g.branch_id,
    COALESCE(g.capacity, 30)::INT,
    COALESCE(g.status, 'active')::TEXT
  FROM public.groups g
  JOIN public.group_teachers gt ON gt.group_id = g.id
  WHERE g.status = 'active'
    AND gt.teacher_id = p_teacher_id
    AND gt.effective_from <= CURRENT_DATE
    AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
  ORDER BY 2;
END;
$$;

CREATE OR REPLACE FUNCTION public.teacher_create_group(
  p_name TEXT,
  p_code TEXT,
  p_subject_id UUID,
  p_branch_id UUID DEFAULT NULL,
  p_capacity INT DEFAULT 30
)
RETURNS public.groups
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID := public.current_teacher_id();
  v_branch_id UUID;
  v_group public.groups;
BEGIN
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Teacher profile is required' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(p_branch_id, t.primary_branch_id)
    INTO v_branch_id
  FROM public.teachers t
  WHERE t.id = v_teacher_id;

  IF v_branch_id IS NULL THEN
    RAISE EXCEPTION 'Teacher branch is required before creating a group' USING ERRCODE = '23502';
  END IF;

  INSERT INTO public.groups (name, code, subject_id, branch_id, capacity, status)
  VALUES (trim(p_name), trim(p_code), p_subject_id, v_branch_id, COALESCE(p_capacity, 30), 'active')
  RETURNING * INTO v_group;

  INSERT INTO public.group_teachers (group_id, teacher_id, role, is_primary, effective_from)
  VALUES (v_group.id, v_teacher_id, 'primary', true, CURRENT_DATE)
  ON CONFLICT (group_id, teacher_id) DO UPDATE
  SET role = 'primary', is_primary = true, effective_to = NULL;

  RETURN v_group;
END;
$$;

CREATE OR REPLACE FUNCTION public.teacher_update_group(
  p_group_id UUID,
  p_name TEXT,
  p_code TEXT,
  p_capacity INT,
  p_status TEXT DEFAULT 'active'
)
RETURNS public.groups
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group public.groups;
BEGIN
  IF NOT public.current_teacher_assigned_to_group(p_group_id) THEN
    RAISE EXCEPTION 'Unauthorized to update group' USING ERRCODE = '42501';
  END IF;

  UPDATE public.groups
  SET name = trim(p_name),
      code = trim(p_code),
      capacity = COALESCE(p_capacity, capacity),
      status = COALESCE(NULLIF(trim(p_status), ''), status),
      updated_at = NOW()
  WHERE id = p_group_id
  RETURNING * INTO v_group;

  RETURN v_group;
END;
$$;

CREATE OR REPLACE FUNCTION public.teacher_archive_group(p_group_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.current_teacher_assigned_to_group(p_group_id) THEN
    RAISE EXCEPTION 'Unauthorized to archive group' USING ERRCODE = '42501';
  END IF;

  UPDATE public.groups
  SET status = 'archived', updated_at = NOW()
  WHERE id = p_group_id;

  UPDATE public.group_teachers
  SET effective_to = CURRENT_DATE
  WHERE group_id = p_group_id
    AND teacher_id = public.current_teacher_id()
    AND effective_to IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.teacher_update_semester(
  p_semester_id UUID,
  p_name TEXT,
  p_code TEXT,
  p_status TEXT DEFAULT 'active'
)
RETURNS public.semesters
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sem public.semesters;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.semesters s
    JOIN public.groups g ON g.subject_id = s.subject_id
    WHERE s.id = p_semester_id
      AND public.current_teacher_assigned_to_group(g.id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to update semester' USING ERRCODE = '42501';
  END IF;

  UPDATE public.semesters
  SET name = trim(p_name),
      code = trim(p_code),
      status = COALESCE(NULLIF(trim(p_status), ''), status),
      updated_at = NOW()
  WHERE id = p_semester_id
  RETURNING * INTO v_sem;

  RETURN v_sem;
END;
$$;

CREATE OR REPLACE FUNCTION public.teacher_update_unit(
  p_unit_id UUID,
  p_name TEXT,
  p_code TEXT,
  p_status TEXT DEFAULT 'active'
)
RETURNS public.units
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_unit public.units;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.units u
    JOIN public.semesters s ON s.id = u.semester_id
    JOIN public.groups g ON g.subject_id = s.subject_id
    WHERE u.id = p_unit_id
      AND public.current_teacher_assigned_to_group(g.id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to update unit' USING ERRCODE = '42501';
  END IF;

  UPDATE public.units
  SET name = trim(p_name),
      code = trim(p_code),
      status = COALESCE(NULLIF(trim(p_status), ''), status),
      updated_at = NOW()
  WHERE id = p_unit_id
  RETURNING * INTO v_unit;

  RETURN v_unit;
END;
$$;

CREATE OR REPLACE FUNCTION public.teacher_update_lesson(
  p_lesson_id UUID,
  p_title TEXT,
  p_lesson_type TEXT,
  p_estimated_duration_minutes INT DEFAULT NULL
)
RETURNS public.lessons
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lesson public.lessons;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.lessons l
    JOIN public.units u ON u.id = l.unit_id
    JOIN public.semesters s ON s.id = u.semester_id
    JOIN public.groups g ON g.subject_id = s.subject_id
    WHERE l.id = p_lesson_id
      AND public.current_teacher_assigned_to_group(g.id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to update lesson' USING ERRCODE = '42501';
  END IF;

  UPDATE public.lessons
  SET title = trim(p_title),
      lesson_type = COALESCE(NULLIF(trim(p_lesson_type), '')::lesson_type, lesson_type),
      estimated_duration_minutes = p_estimated_duration_minutes,
      updated_at = NOW()
  WHERE id = p_lesson_id
  RETURNING * INTO v_lesson;

  RETURN v_lesson;
END;
$$;

CREATE OR REPLACE FUNCTION public.teacher_update_lesson_resource(
  p_resource_id UUID,
  p_title TEXT
)
RETURNS public.lesson_resources
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_resource public.lesson_resources;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.lesson_resources lr
    JOIN public.lessons l ON l.id = lr.lesson_id
    JOIN public.units u ON u.id = l.unit_id
    JOIN public.semesters s ON s.id = u.semester_id
    JOIN public.groups g ON g.subject_id = s.subject_id
    WHERE lr.id = p_resource_id
      AND public.current_teacher_assigned_to_group(g.id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to update resource' USING ERRCODE = '42501';
  END IF;

  UPDATE public.lesson_resources
  SET title = trim(p_title), updated_at = NOW()
  WHERE id = p_resource_id
  RETURNING * INTO v_resource;

  RETURN v_resource;
END;
$$;

GRANT EXECUTE ON FUNCTION public.teacher_create_group(TEXT, TEXT, UUID, UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teacher_update_group(UUID, TEXT, TEXT, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teacher_archive_group(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teacher_update_semester(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teacher_update_unit(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teacher_update_lesson(UUID, TEXT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teacher_update_lesson_resource(UUID, TEXT) TO authenticated;

ALTER TABLE public.attendance_records
  ADD COLUMN IF NOT EXISTS check_out_at TIMESTAMPTZ;

DROP FUNCTION IF EXISTS public.get_teacher_session_attendance_roster(UUID);
CREATE OR REPLACE FUNCTION public.get_teacher_session_attendance_roster(
  p_class_session_id UUID
)
RETURNS TABLE (
  student_id UUID,
  student_code TEXT,
  full_name TEXT,
  attendance_status TEXT,
  check_in_at TIMESTAMPTZ,
  check_out_at TIMESTAMPTZ,
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
    RAISE EXCEPTION 'Unauthorized to view attendance roster' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    COALESCE(s.student_code, '')::TEXT,
    COALESCE(p.full_name, s.student_code, 'Student')::TEXT,
    COALESCE(ar.attendance_status, 'pending')::TEXT,
    COALESCE(ar.check_in_at, ar.arrival_at, ar.marked_at),
    ar.check_out_at,
    ar.device_id,
    ar.latitude,
    ar.longitude,
    (ar.qr_session_id IS NOT NULL)::BOOLEAN
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

DROP FUNCTION IF EXISTS public.mark_student_checkout(UUID, UUID);
CREATE OR REPLACE FUNCTION public.mark_student_checkout(
  p_class_session_id UUID,
  p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cs RECORD;
  updated_id UUID;
BEGIN
  SELECT * INTO cs FROM public.class_sessions WHERE id = p_class_session_id;
  IF cs.id IS NULL THEN
    RAISE EXCEPTION 'Class session not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('attendance.mark')
    OR public.current_teacher_assigned_to_group(cs.group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to mark checkout' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.enrollments
    WHERE group_id = cs.group_id
      AND student_id = p_student_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Student is not enrolled in this group' USING ERRCODE = '22000';
  END IF;

  UPDATE public.attendance_records
  SET check_out_at = NOW(), updated_at = NOW()
  WHERE class_session_id = p_class_session_id
    AND student_id = p_student_id
    AND attendance_status IN ('present', 'late')
  RETURNING id INTO updated_id;

  IF updated_id IS NULL THEN
    RAISE EXCEPTION 'Student has no present/late attendance record' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object('success', true, 'student_id', p_student_id, 'class_session_id', p_class_session_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_teacher_session_attendance_roster(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mark_student_checkout(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_session_attendance_roster(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_student_checkout(UUID, UUID) TO authenticated;

DROP FUNCTION IF EXISTS public.get_teacher_student_receipts(UUID, UUID);
CREATE OR REPLACE FUNCTION public.get_teacher_student_receipts(
  p_student_id UUID,
  p_group_id UUID
)
RETURNS TABLE (
  receipt_id UUID,
  receipt_number TEXT,
  invoice_id UUID,
  invoice_number TEXT,
  transaction_id UUID,
  provider TEXT,
  provider_transaction_id TEXT,
  payment_method TEXT,
  amount_minor BIGINT,
  currency TEXT,
  issued_at TIMESTAMPTZ,
  student_name TEXT,
  student_code TEXT,
  group_name TEXT,
  group_code TEXT,
  subject_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('payments.view')
    OR public.has_permission('payments.collect')
    OR public.current_teacher_assigned_to_group(p_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view student receipts' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.enrollments
    WHERE group_id = p_group_id
      AND student_id = p_student_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Student is not active in this group' USING ERRCODE = '22000';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.receipt_number,
    r.invoice_id,
    inv.invoice_number,
    r.transaction_id,
    COALESCE(pt.provider, 'cash')::TEXT,
    pt.provider_transaction_id,
    COALESCE(pt.provider, 'cash')::TEXT,
    r.amount_minor,
    r.currency,
    r.issued_at,
    COALESCE(p.full_name, st.student_code, 'Student')::TEXT,
    COALESCE(st.student_code, '')::TEXT,
    g.name,
    g.code,
    COALESCE(sub.name, '')::TEXT
  FROM public.receipts r
  JOIN public.students st ON st.id = r.student_id
  LEFT JOIN public.profiles p ON p.id = st.profile_id
  LEFT JOIN public.invoices inv ON inv.id = r.invoice_id
  LEFT JOIN public.payment_transactions pt ON pt.id = r.transaction_id
  JOIN public.enrollments e
    ON e.student_id = st.id
   AND e.group_id = p_group_id
   AND e.status = 'active'
  JOIN public.groups g ON g.id = e.group_id
  LEFT JOIN public.subjects sub ON sub.id = g.subject_id
  WHERE r.student_id = p_student_id
  ORDER BY r.issued_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_teacher_student_receipts(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_student_receipts(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.bridge_app_notification_to_push_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF to_regclass('public.notifications') IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (
    user_id,
    notification_type,
    title,
    body,
    data,
    created_at
  )
  VALUES (
    NEW.user_id,
    COALESCE(NULLIF(NEW.type, ''), 'app'),
    NEW.title,
    NEW.message,
    jsonb_build_object(
      'app_notification_id', NEW.id,
      'reference_id', NEW.reference_id,
      'type', NEW.type
    ),
    NEW.created_at
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS bridge_app_notification_to_push_trigger ON public.app_notifications;
CREATE TRIGGER bridge_app_notification_to_push_trigger
AFTER INSERT ON public.app_notifications
FOR EACH ROW EXECUTE FUNCTION public.bridge_app_notification_to_push_notification();

NOTIFY pgrst, 'reload schema';
