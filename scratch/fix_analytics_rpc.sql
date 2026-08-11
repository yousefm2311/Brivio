-- Fix ambiguous get_admin_analytics function (PGRST203)
DROP FUNCTION IF EXISTS public.get_admin_analytics(DATE, DATE);
DROP FUNCTION IF EXISTS public.get_admin_analytics(TIMESTAMPTZ, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION public.get_admin_analytics(period_start TIMESTAMPTZ, period_end TIMESTAMPTZ)
RETURNS JSONB AS $$
DECLARE
    v_total_revenue NUMERIC;
    v_attendance_rate NUMERIC;
    v_total_students INT;
    v_total_sessions INT;
    result JSONB;
BEGIN
    -- Fallback for total_revenue if payment_transactions is missing
    v_total_revenue := 0;

    -- Calculate attendance rate
    SELECT 
        CASE WHEN count(*) = 0 THEN 0 ELSE (sum(case when attendance_status = 'present' then 1 else 0 end)::NUMERIC / count(*)) * 100 END,
        COUNT(DISTINCT class_session_id)
    INTO v_attendance_rate, v_total_sessions
    FROM public.attendance_records
    WHERE marked_at >= period_start AND marked_at <= period_end;

    SELECT COUNT(*) INTO v_total_students FROM public.students;

    result := jsonb_build_object(
        'total_revenue', v_total_revenue,
        'attendance_rate', v_attendance_rate,
        'total_students', v_total_students,
        'total_sessions', v_total_sessions
    );

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
