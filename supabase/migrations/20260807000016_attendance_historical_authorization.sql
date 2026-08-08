-- Migration: 20260807000016_attendance_historical_authorization.sql
-- Description: Phase 7.75 Historical Attendance Authorization Patch

-- 1. Date-Aware Teacher Group Assignment Helper
CREATE OR REPLACE FUNCTION public.current_teacher_assigned_to_group_on_date(
    target_group_id UUID,
    target_date DATE
)
RETURNS BOOLEAN AS $$
DECLARE
    t_id UUID;
BEGIN
    t_id := public.current_teacher_id();
    IF t_id IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.group_teachers
        WHERE group_id = target_group_id
          AND teacher_id = t_id
          AND effective_from <= target_date
          AND (effective_to IS NULL OR effective_to >= target_date)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.current_teacher_assigned_to_group_on_date(UUID, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_teacher_assigned_to_group_on_date(UUID, DATE) TO authenticated;

-- 2. Helper: Validate Student Historical Enrollment on Date
CREATE OR REPLACE FUNCTION public.student_enrolled_in_group_on_date(
    p_student_id UUID,
    p_group_id UUID,
    p_date DATE
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.enrollments
        WHERE student_id = p_student_id
          AND group_id = p_group_id
          AND start_date <= p_date
          AND (end_date IS NULL OR end_date >= p_date)
          AND status IN ('active', 'completed')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.student_enrolled_in_group_on_date(UUID, UUID, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.student_enrolled_in_group_on_date(UUID, UUID, DATE) TO authenticated;

-- 3. Update get_session_roster with Date-Aware Teacher Authorization & Canonical Historical Roster
CREATE OR REPLACE FUNCTION public.get_session_roster(p_session_id UUID)
RETURNS JSONB AS $$
DECLARE
    cs RECORD;
    roster_list JSONB;
BEGIN
    SELECT * INTO cs FROM public.class_sessions WHERE id = p_session_id;
    IF cs.id IS NULL THEN
        RAISE EXCEPTION 'Class session not found' USING ERRCODE = '44000';
    END IF;

    IF NOT (
        public.is_admin_or_super() OR
        public.has_permission('attendance.view') OR
        public.current_teacher_assigned_to_group_on_date(cs.group_id, cs.session_date)
    ) THEN
        RAISE EXCEPTION 'Unauthorized to view roster for this class session' USING ERRCODE = '42501';
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'student_id', st.student_id,
            'first_name', st.first_name,
            'last_name', st.last_name,
            'student_code', st.student_code,
            'attendance_status', ar.attendance_status,
            'attendance_source', st.source_type,
            'marked_at', ar.marked_at,
            'notes', ar.notes
        ) ORDER BY st.last_name, st.first_name
    ) INTO roster_list
    FROM (
        -- Regular enrolled students at session date
        SELECT s.id AS student_id, p.first_name, p.last_name, s.student_code, 'regular' AS source_type
        FROM public.enrollments e
        JOIN public.students s ON s.id = e.student_id
        JOIN public.profiles p ON p.id = s.profile_id
        WHERE e.group_id = cs.group_id
          AND e.start_date <= cs.session_date
          AND (e.end_date IS NULL OR e.end_date >= cs.session_date)
          AND e.status IN ('active', 'completed')

        UNION ALL

        -- Approved compensation make-up students for target session
        SELECT s.id AS student_id, p.first_name, p.last_name, s.student_code, 'compensation' AS source_type
        FROM public.compensation_requests cr
        JOIN public.students s ON s.id = cr.student_id
        JOIN public.profiles p ON p.id = s.profile_id
        WHERE cr.target_session_id = p_session_id AND cr.status IN ('approved', 'completed')
    ) st
    LEFT JOIN public.attendance_records ar ON ar.class_session_id = p_session_id AND ar.student_id = st.student_id;

    RETURN jsonb_build_object(
        'session_id', cs.id,
        'group_id', cs.group_id,
        'session_date', cs.session_date,
        'status', cs.status,
        'finalized', (cs.attendance_finalized_at IS NOT NULL),
        'roster', COALESCE(roster_list, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Update mark_session_attendance with Session-Date Eligibility Validation
CREATE OR REPLACE FUNCTION public.mark_session_attendance(
    p_session_id UUID,
    p_records JSONB
)
RETURNS JSONB AS $$
DECLARE
    cs RECORD;
    rec RECORD;
    s_id UUID;
    st TEXT;
    arr TIMESTAMPTZ;
    nt TEXT;
    marked_count INT := 0;
BEGIN
    SELECT * INTO cs FROM public.class_sessions WHERE id = p_session_id;
    IF cs.id IS NULL THEN
        RAISE EXCEPTION 'Class session not found' USING ERRCODE = '44000';
    END IF;

    IF NOT (
        public.is_admin_or_super() OR
        public.has_permission('attendance.mark') OR
        public.current_teacher_assigned_to_group_on_date(cs.group_id, cs.session_date)
    ) THEN
        RAISE EXCEPTION 'Unauthorized to mark attendance for this class session' USING ERRCODE = '42501';
    END IF;

    FOR rec IN SELECT * FROM jsonb_to_recordset(p_records) AS x(
        student_id UUID,
        attendance_status TEXT,
        arrival_at TIMESTAMPTZ,
        notes TEXT
    ) LOOP
        s_id := rec.student_id;
        st := rec.attendance_status;
        arr := rec.arrival_at;
        nt := rec.notes;

        -- Verify student belongs to group enrollment roster on session date (or is approved compensation)
        IF NOT (
            public.student_enrolled_in_group_on_date(s_id, cs.group_id, cs.session_date) OR
            EXISTS (
                SELECT 1 FROM public.compensation_requests
                WHERE student_id = s_id AND target_session_id = p_session_id AND status IN ('approved', 'completed')
            )
        ) THEN
            RAISE EXCEPTION 'Student % is not eligible for session date %', s_id, cs.session_date USING ERRCODE = '22000';
        END IF;

        INSERT INTO public.attendance_records (
            class_session_id, student_id, attendance_status, marked_by, marked_at, arrival_at, notes
        )
        VALUES (
            p_session_id, s_id, st, auth.uid(), NOW(), arr, nt
        )
        ON CONFLICT (class_session_id, student_id) DO UPDATE SET
            attendance_status = EXCLUDED.attendance_status,
            marked_by = auth.uid(),
            marked_at = NOW(),
            arrival_at = EXCLUDED.arrival_at,
            notes = EXCLUDED.notes,
            updated_at = NOW();

        marked_count := marked_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'session_id', p_session_id, 'marked_count', marked_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 5. Update finalize_session_attendance to Use Identical Historical Enrollment Roster Logic
CREATE OR REPLACE FUNCTION public.finalize_session_attendance(p_session_id UUID)
RETURNS JSONB AS $$
DECLARE
    cs RECORD;
    enr RECORD;
    absent_count INT := 0;
BEGIN
    SELECT * INTO cs FROM public.class_sessions WHERE id = p_session_id;
    IF cs.id IS NULL THEN
        RAISE EXCEPTION 'Class session not found' USING ERRCODE = '44000';
    END IF;

    IF NOT (
        public.is_admin_or_super() OR
        public.has_permission('attendance.finalize') OR
        public.current_teacher_assigned_to_group_on_date(cs.group_id, cs.session_date)
    ) THEN
        RAISE EXCEPTION 'Unauthorized to finalize attendance' USING ERRCODE = '42501';
    END IF;

    -- Mark remaining historically eligible group students without attendance as absent
    FOR enr IN
        SELECT e.student_id
        FROM public.enrollments e
        WHERE e.group_id = cs.group_id
          AND e.start_date <= cs.session_date
          AND (e.end_date IS NULL OR e.end_date >= cs.session_date)
          AND e.status IN ('active', 'completed')
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.attendance_records WHERE class_session_id = p_session_id AND student_id = enr.student_id
        ) THEN
            INSERT INTO public.attendance_records (
                class_session_id, student_id, attendance_status, marked_by, marked_at, notes
            )
            VALUES (
                p_session_id, enr.student_id, 'absent', auth.uid(), NOW(), 'Auto-marked absent on roll call finalization'
            );
            absent_count := absent_count + 1;
        END IF;
    END LOOP;

    UPDATE public.class_sessions
    SET status = 'completed',
        attendance_finalized_at = NOW(),
        attendance_finalized_by = auth.uid(),
        updated_at = NOW()
    WHERE id = p_session_id;

    RETURN jsonb_build_object('success', true, 'session_id', p_session_id, 'auto_absent_count', absent_count, 'status', 'completed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
