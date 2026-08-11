-- 1. Create SQL RPC for get_admin_analytics
CREATE OR REPLACE FUNCTION public.get_admin_analytics(period_start TIMESTAMPTZ, period_end TIMESTAMPTZ)
RETURNS JSON AS $$
DECLARE
    v_total_revenue DOUBLE PRECISION;
    v_attendance_rate DOUBLE PRECISION;
    v_total_students INT;
    v_total_sessions INT;
BEGIN
    -- Calculate total revenue
    SELECT COALESCE(SUM(amount_minor) / 100.0, 0)
    INTO v_total_revenue
    FROM public.payment_transactions
    WHERE status = 'succeeded'
      AND transaction_type = 'payment'
      AND occurred_at >= period_start
      AND occurred_at <= period_end;

    -- Calculate average attendance rate
    SELECT COALESCE(
             (COUNT(*) FILTER (WHERE attendance_status IN ('present', 'late')) * 100.0) / NULLIF(COUNT(*), 0),
             0
           )
    INTO v_attendance_rate
    FROM public.attendance_records
    WHERE marked_at >= period_start
      AND marked_at <= period_end;

    -- Calculate active students
    SELECT COUNT(*)
    INTO v_total_students
    FROM public.students
    WHERE status = 'active';

    -- Calculate total sessions in the period
    SELECT COUNT(*)
    INTO v_total_sessions
    FROM public.class_sessions
    WHERE scheduled_start_at >= period_start
      AND scheduled_start_at <= period_end;

    RETURN json_build_object(
        'total_revenue', v_total_revenue,
        'attendance_rate', v_attendance_rate,
        'total_students', v_total_students,
        'total_sessions', v_total_sessions
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
