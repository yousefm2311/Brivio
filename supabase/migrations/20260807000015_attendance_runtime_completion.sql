-- Migration: 20260807000015_attendance_runtime_completion.sql
-- Description: Attendance Historical Integrity, Session Roster RPC, Controlled Session Generation, & Compensation Engine Completion

-- 1. Add Attendance Finalization Metadata to class_sessions
ALTER TABLE public.class_sessions
    ADD COLUMN IF NOT EXISTS attendance_finalized_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS attendance_finalized_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 2. Historical Session Roster RPC (Resolves Enrolled Students at Session Date + Approved Compensation Attendees)
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

    IF NOT (public.is_admin_or_super() OR public.has_permission('attendance.view') OR public.current_teacher_assigned_to_group(cs.group_id)) THEN
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
          AND e.enrolled_at::date <= cs.session_date

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

-- 3. Controlled Group Session Generation RPC
CREATE OR REPLACE FUNCTION public.generate_group_sessions(
    p_group_id UUID,
    p_from_date DATE,
    p_to_date DATE
)
RETURNS JSONB AS $$
DECLARE
    sch RECORD;
    curr_date DATE;
    gen_count INT := 0;
    sched_start TIMESTAMPTZ;
    sched_end TIMESTAMPTZ;
BEGIN
    IF NOT (public.is_admin_or_super() OR public.has_permission('groups.create')) THEN
        RAISE EXCEPTION 'Unauthorized to generate group sessions' USING ERRCODE = '42501';
    END IF;

    IF p_to_date < p_from_date OR (p_to_date - p_from_date) > 90 THEN
        RAISE EXCEPTION 'Invalid date range for session generation (max 90 days)' USING ERRCODE = '22023';
    END IF;

    FOR sch IN SELECT * FROM public.schedules WHERE group_id = p_group_id AND status = 'active' LOOP
        curr_date := p_from_date;
        WHILE curr_date <= p_to_date LOOP
            -- ISO day of week (1 = Monday, 7 = Sunday)
            IF EXTRACT(ISODOW FROM curr_date) = sch.day_of_week THEN
                sched_start := (curr_date || ' ' || sch.start_time)::TIMESTAMPTZ;
                sched_end := (curr_date || ' ' || sch.end_time)::TIMESTAMPTZ;

                INSERT INTO public.class_sessions (
                    group_id, schedule_id, session_date, scheduled_start_at, scheduled_end_at, status, location
                )
                VALUES (
                    p_group_id, sch.id, curr_date, sched_start, sched_end, 'scheduled', sch.location
                )
                ON CONFLICT (group_id, session_date, scheduled_start_at) DO NOTHING;

                gen_count := gen_count + 1;
            END IF;
            curr_date := curr_date + 1;
        END LOOP;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'group_id', p_group_id, 'generated_count', gen_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Server-Authoritative Compensation Session Assignment RPC (Capacity & Subject Compatibility Safe)
CREATE OR REPLACE FUNCTION public.assign_compensation_session(
    p_request_id UUID,
    p_target_session_id UUID
)
RETURNS JSONB AS $$
DECLARE
    req RECORD;
    orig_cs RECORD;
    targ_cs RECORD;
    orig_sub UUID;
    targ_sub UUID;
    current_occupancy INT;
    target_capacity INT;
BEGIN
    IF NOT (public.is_admin_or_super() OR public.has_permission('compensation.manage')) THEN
        RAISE EXCEPTION 'Unauthorized to assign compensation' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO req FROM public.compensation_requests WHERE id = p_request_id;
    IF req.id IS NULL THEN
        RAISE EXCEPTION 'Compensation request not found' USING ERRCODE = '44000';
    END IF;

    SELECT * INTO orig_cs FROM public.class_sessions WHERE id = req.original_session_id;
    SELECT * INTO targ_cs FROM public.class_sessions WHERE id = p_target_session_id;

    IF orig_cs.id IS NULL OR targ_cs.id IS NULL THEN
        RAISE EXCEPTION 'Original or target class session invalid' USING ERRCODE = '44000';
    END IF;

    -- Verify Subject Compatibility
    SELECT subject_id INTO orig_sub FROM public.groups WHERE id = orig_cs.group_id;
    SELECT subject_id INTO targ_sub FROM public.groups WHERE id = targ_cs.group_id;

    IF orig_sub != targ_sub THEN
        RAISE EXCEPTION 'Target session subject does not match original session subject' USING ERRCODE = '22000';
    END IF;

    -- Lock target group row to prevent capacity race condition
    SELECT max_capacity INTO target_capacity FROM public.groups WHERE id = targ_cs.group_id FOR UPDATE;

    SELECT COUNT(*)::int INTO current_occupancy
    FROM public.enrollments WHERE group_id = targ_cs.group_id AND status = 'active';

    IF target_capacity IS NOT NULL AND current_occupancy >= target_capacity THEN
        RAISE EXCEPTION 'Target group has reached maximum capacity' USING ERRCODE = '54000';
    END IF;

    UPDATE public.compensation_requests
    SET target_session_id = p_target_session_id,
        status = 'approved',
        approved_by = auth.uid(),
        updated_at = NOW()
    WHERE id = p_request_id;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', p_request_id,
        'target_session_id', p_target_session_id,
        'status', 'approved'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 5. Student Attendance Summary RPC (Server-Authoritative Percentage Calculation)
CREATE OR REPLACE FUNCTION public.get_student_attendance_summary(p_student_id UUID)
RETURNS JSONB AS $$
DECLARE
    total_sess INT := 0;
    p_cnt INT := 0;
    a_cnt INT := 0;
    l_cnt INT := 0;
    e_cnt INT := 0;
    denom INT;
    pct NUMERIC(5,2);
BEGIN
    SELECT
        COUNT(*)::int,
        COALESCE(SUM(CASE WHEN attendance_status = 'present' THEN 1 ELSE 0 END), 0)::int,
        COALESCE(SUM(CASE WHEN attendance_status = 'absent' THEN 1 ELSE 0 END), 0)::int,
        COALESCE(SUM(CASE WHEN attendance_status = 'late' THEN 1 ELSE 0 END), 0)::int,
        COALESCE(SUM(CASE WHEN attendance_status = 'excused' THEN 1 ELSE 0 END), 0)::int
    INTO total_sess, p_cnt, a_cnt, l_cnt, e_cnt
    FROM public.attendance_records
    WHERE student_id = p_student_id;

    denom := p_cnt + l_cnt + a_cnt;
    IF denom > 0 THEN
        pct := ROUND(((p_cnt + (l_cnt * 0.8)) / denom::numeric * 100.0), 2);
    ELSE
        pct := 100.00;
    END IF;

    RETURN jsonb_build_object(
        'student_id', p_student_id,
        'total_sessions', total_sess,
        'present_count', p_cnt,
        'absent_count', a_cnt,
        'late_count', l_cnt,
        'excused_count', e_cnt,
        'attendance_percentage', pct
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.get_session_roster(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_session_roster(UUID) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_group_sessions(UUID, DATE, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_group_sessions(UUID, DATE, DATE) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.assign_compensation_session(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assign_compensation_session(UUID, UUID) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_student_attendance_summary(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_student_attendance_summary(UUID) TO authenticated;
