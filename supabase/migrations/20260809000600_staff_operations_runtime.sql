-- Migration: 20260809000600_staff_operations_runtime.sql
-- Description: Staff queue action for resolving attendance exceptions.

DROP FUNCTION IF EXISTS public.staff_update_attendance_exception(UUID, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.staff_update_attendance_exception(
  p_attendance_record_id UUID,
  p_attendance_status TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rec RECORD;
BEGIN
  IF p_attendance_status NOT IN ('present', 'late', 'absent', 'excused') THEN
    RAISE EXCEPTION 'Invalid attendance status' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('attendance.manage')
    OR public.current_user_role() = 'staff'
  ) THEN
    RAISE EXCEPTION 'Unauthorized to resolve attendance exceptions'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO rec
  FROM public.attendance_records
  WHERE id = p_attendance_record_id
  FOR UPDATE;

  IF rec.id IS NULL THEN
    RAISE EXCEPTION 'Attendance record not found' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.attendance_records
  SET
    attendance_status = p_attendance_status,
    marked_by = auth.uid(),
    marked_at = NOW(),
    notes = COALESCE(NULLIF(trim(p_notes), ''), notes),
    updated_at = NOW()
  WHERE id = p_attendance_record_id;

  RETURN jsonb_build_object(
    'success', true,
    'attendance_record_id', p_attendance_record_id,
    'attendance_status', p_attendance_status
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.staff_update_attendance_exception(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.staff_update_attendance_exception(UUID, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
