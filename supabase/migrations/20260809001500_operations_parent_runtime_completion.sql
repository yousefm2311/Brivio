-- Migration: 20260809001500_operations_parent_runtime_completion.sql
-- Description: Stable staff operations queue and parent child summary RPCs.

CREATE OR REPLACE FUNCTION public.get_staff_operations_queue(p_limit INT DEFAULT 50)
RETURNS TABLE (
  item_type TEXT,
  item_id UUID,
  title TEXT,
  subtitle TEXT,
  status TEXT,
  amount_minor BIGINT,
  currency TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.current_user_role() = 'staff'
    OR public.has_permission('attendance.manage')
    OR public.has_permission('payments.collect')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view operations queue' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH queue AS (
    SELECT
      'leave'::TEXT AS item_type,
      lr.id AS item_id,
      COALESCE(sp.full_name, st.student_code, 'Student') AS title,
      CONCAT_WS(' - ', g.name, lr.reason) AS subtitle,
      lr.status::TEXT AS status,
      0::BIGINT AS amount_minor,
      'EGP'::TEXT AS currency,
      lr.submitted_at AS created_at
    FROM public.leave_requests lr
    JOIN public.students st ON st.id = lr.student_id
    JOIN public.profiles sp ON sp.id = st.profile_id
    LEFT JOIN public.class_sessions cs ON cs.id = lr.class_session_id
    LEFT JOIN public.groups g ON g.id = cs.group_id
    WHERE lr.status = 'pending'

    UNION ALL

    SELECT
      'invoice'::TEXT AS item_type,
      inv.id AS item_id,
      COALESCE(inv.invoice_number, 'Invoice') AS title,
      COALESCE(sp.full_name, st.student_code, 'Student') AS subtitle,
      inv.status::TEXT AS status,
      GREATEST(inv.total_minor - inv.amount_paid_minor, 0)::BIGINT AS amount_minor,
      inv.currency,
      inv.due_at AS created_at
    FROM public.invoices inv
    JOIN public.students st ON st.id = inv.student_id
    JOIN public.profiles sp ON sp.id = st.profile_id
    WHERE inv.status IN ('issued', 'overdue', 'partially_paid')

    UNION ALL

    SELECT
      'attendance'::TEXT AS item_type,
      ar.id AS item_id,
      COALESCE(sp.full_name, st.student_code, 'Student') AS title,
      CONCAT_WS(' - ', g.name, cs.session_date::TEXT) AS subtitle,
      ar.attendance_status::TEXT AS status,
      0::BIGINT AS amount_minor,
      'EGP'::TEXT AS currency,
      COALESCE(ar.marked_at, cs.session_date::TIMESTAMPTZ) AS created_at
    FROM public.attendance_records ar
    JOIN public.students st ON st.id = ar.student_id
    JOIN public.profiles sp ON sp.id = st.profile_id
    LEFT JOIN public.class_sessions cs ON cs.id = ar.class_session_id
    LEFT JOIN public.groups g ON g.id = cs.group_id
    WHERE ar.attendance_status IN ('absent', 'late')

    UNION ALL

    SELECT
      'adjustment'::TEXT AS item_type,
      par.id AS item_id,
      COALESCE(sp.full_name, st.student_code, 'Student') AS title,
      CONCAT_WS(' - ', g.name, par.adjustment_type) AS subtitle,
      par.status::TEXT AS status,
      par.requested_discount_minor AS amount_minor,
      par.currency,
      par.requested_at AS created_at
    FROM public.payment_adjustment_requests par
    JOIN public.students st ON st.id = par.student_id
    JOIN public.profiles sp ON sp.id = st.profile_id
    JOIN public.groups g ON g.id = par.group_id
    WHERE par.status = 'pending'
  )
  SELECT *
  FROM queue
  ORDER BY created_at DESC NULLS LAST
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
END;
$$;

CREATE OR REPLACE FUNCTION public.get_parent_child_summary(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_attendance_total BIGINT;
  v_attendance_present BIGINT;
  v_invoice_due BIGINT;
  v_invoice_paid BIGINT;
  v_open_leave BIGINT;
  v_active_groups BIGINT;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('students.view')
    OR public.current_parent_has_student(p_student_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view child summary' USING ERRCODE = '42501';
  END IF;

  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE attendance_status IN ('present', 'late', 'excused'))
  INTO v_attendance_total, v_attendance_present
  FROM public.attendance_records
  WHERE student_id = p_student_id;

  SELECT
    COALESCE(SUM(total_minor), 0),
    COALESCE(SUM(amount_paid_minor), 0)
  INTO v_invoice_due, v_invoice_paid
  FROM public.invoices
  WHERE student_id = p_student_id
    AND status <> 'cancelled';

  SELECT COUNT(*)
  INTO v_open_leave
  FROM public.leave_requests
  WHERE student_id = p_student_id
    AND status = 'pending';

  SELECT COUNT(*)
  INTO v_active_groups
  FROM public.enrollments
  WHERE student_id = p_student_id
    AND status = 'active'
    AND COALESCE(access_status, 'active') = 'active';

  RETURN jsonb_build_object(
    'student_id', p_student_id,
    'active_groups', COALESCE(v_active_groups, 0),
    'attendance_total', COALESCE(v_attendance_total, 0),
    'attendance_present', COALESCE(v_attendance_present, 0),
    'attendance_percentage', CASE
      WHEN COALESCE(v_attendance_total, 0) = 0 THEN 100
      ELSE ROUND((v_attendance_present::NUMERIC / v_attendance_total::NUMERIC) * 100, 1)
    END,
    'total_due_minor', COALESCE(v_invoice_due, 0),
    'total_paid_minor', COALESCE(v_invoice_paid, 0),
    'remaining_balance_minor', GREATEST(COALESCE(v_invoice_due, 0) - COALESCE(v_invoice_paid, 0), 0),
    'pending_leave_requests', COALESCE(v_open_leave, 0)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_staff_operations_queue(INT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_parent_child_summary(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_staff_operations_queue(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_parent_child_summary(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
