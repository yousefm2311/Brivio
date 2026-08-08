-- Migration: 20260807000014_attendance_engine.sql
-- Description: Phase 7 Attendance, Class Sessions, Leave Requests & Compensation Engine

-- 1. Class Sessions Table (Dated Occurrences of Groups)
CREATE TABLE IF NOT EXISTS public.class_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    schedule_id UUID REFERENCES public.schedules(id) ON DELETE SET NULL,
    session_date DATE NOT NULL,
    scheduled_start_at TIMESTAMPTZ NOT NULL,
    scheduled_end_at TIMESTAMPTZ NOT NULL,
    actual_start_at TIMESTAMPTZ,
    actual_end_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
    location TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_group_session_slot UNIQUE (group_id, session_date, scheduled_start_at)
);

-- 2. Attendance Records Table
CREATE TABLE IF NOT EXISTS public.attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_session_id UUID NOT NULL REFERENCES public.class_sessions(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    attendance_status TEXT NOT NULL CHECK (attendance_status IN ('present', 'absent', 'late', 'excused')),
    marked_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    marked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    arrival_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_session_student_attendance UNIQUE (class_session_id, student_id)
);

-- 3. Leave Requests Table
CREATE TABLE IF NOT EXISTS public.leave_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    class_session_id UUID REFERENCES public.class_sessions(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    reviewer_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Compensation / Make-Up Requests Table
CREATE TABLE IF NOT EXISTS public.compensation_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    original_session_id UUID NOT NULL REFERENCES public.class_sessions(id) ON DELETE CASCADE,
    target_session_id UUID NOT NULL REFERENCES public.class_sessions(id) ON DELETE CASCADE,
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'completed', 'rejected')),
    requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_student_compensation UNIQUE (student_id, original_session_id)
);

-- 5. Enable RLS on all Phase 7 tables
ALTER TABLE public.class_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compensation_requests ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies
CREATE POLICY "Class sessions viewable by authorized users"
ON public.class_sessions FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('attendance.view') OR
    public.current_teacher_assigned_to_group(group_id) OR
    EXISTS (
        SELECT 1 FROM public.students s
        JOIN public.enrollments e ON e.student_id = s.id
        WHERE s.profile_id = auth.uid() AND e.group_id = class_sessions.group_id AND e.status = 'active'
    )
);

CREATE POLICY "Attendance records viewable by authorized users"
ON public.attendance_records FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('attendance.view') OR
    EXISTS (
        SELECT 1 FROM public.students s WHERE s.id = attendance_records.student_id AND s.profile_id = auth.uid()
    ) OR
    EXISTS (
        SELECT 1 FROM public.class_sessions cs
        WHERE cs.id = attendance_records.class_session_id AND public.current_teacher_assigned_to_group(cs.group_id)
    )
);

CREATE POLICY "Leave requests viewable by owner or authorized staff"
ON public.leave_requests FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('leave.view') OR
    EXISTS (
        SELECT 1 FROM public.students s WHERE s.id = leave_requests.student_id AND s.profile_id = auth.uid()
    )
);

CREATE POLICY "Compensation requests viewable by owner or authorized staff"
ON public.compensation_requests FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('compensation.view') OR
    EXISTS (
        SELECT 1 FROM public.students s WHERE s.id = compensation_requests.student_id AND s.profile_id = auth.uid()
    )
);

-- 7. Server-Authoritative Attendance RPCs

-- Atomic Bulk Attendance Marking RPC
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

    IF NOT (public.is_admin_or_super() OR public.has_permission('attendance.mark') OR public.current_teacher_assigned_to_group(cs.group_id)) THEN
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

        -- Verify student belongs to group enrollment roster
        IF NOT EXISTS (
            SELECT 1 FROM public.enrollments
            WHERE group_id = cs.group_id AND student_id = s_id AND status = 'active'
        ) THEN
            RAISE EXCEPTION 'Student % is not actively enrolled in session group', s_id USING ERRCODE = '22000';
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

-- Finalize Session Attendance RPC (Auto-marks unmarked roster students as absent)
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

    IF NOT (public.is_admin_or_super() OR public.has_permission('attendance.finalize') OR public.current_teacher_assigned_to_group(cs.group_id)) THEN
        RAISE EXCEPTION 'Unauthorized to finalize attendance' USING ERRCODE = '42501';
    END IF;

    -- Mark remaining active group students without attendance as absent
    FOR enr IN SELECT student_id FROM public.enrollments WHERE group_id = cs.group_id AND status = 'active' LOOP
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

    UPDATE public.class_sessions SET status = 'completed', updated_at = NOW() WHERE id = p_session_id;

    RETURN jsonb_build_object('success', true, 'session_id', p_session_id, 'auto_absent_count', absent_count, 'status', 'completed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Leave Request Review RPC (Integrates with Attendance)
CREATE OR REPLACE FUNCTION public.review_leave_request(
    p_request_id UUID,
    p_decision TEXT,
    p_reviewer_note TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    req RECORD;
BEGIN
    IF NOT (public.is_admin_or_super() OR public.has_permission('leave.review')) THEN
        RAISE EXCEPTION 'Unauthorized to review leave requests' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO req FROM public.leave_requests WHERE id = p_request_id;
    IF req.id IS NULL THEN
        RAISE EXCEPTION 'Leave request not found' USING ERRCODE = '44000';
    END IF;

    IF p_decision NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Invalid review decision' USING ERRCODE = '22023';
    END IF;

    UPDATE public.leave_requests
    SET status = p_decision,
        reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        reviewer_note = p_reviewer_note,
        updated_at = NOW()
    WHERE id = p_request_id;

    -- If approved and session ID is attached, update attendance status to excused
    IF p_decision = 'approved' AND req.class_session_id IS NOT NULL THEN
        INSERT INTO public.attendance_records (
            class_session_id, student_id, attendance_status, marked_by, marked_at, notes
        )
        VALUES (
            req.class_session_id, req.student_id, 'excused', auth.uid(), NOW(), 'Excused via approved leave request'
        )
        ON CONFLICT (class_session_id, student_id) DO UPDATE SET
            attendance_status = 'excused',
            marked_by = auth.uid(),
            marked_at = NOW(),
            notes = 'Excused via approved leave request',
            updated_at = NOW();
    END IF;

    RETURN jsonb_build_object('success', true, 'request_id', p_request_id, 'status', p_decision);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.mark_session_attendance(UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_session_attendance(UUID, JSONB) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.finalize_session_attendance(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.finalize_session_attendance(UUID) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.review_leave_request(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.review_leave_request(UUID, TEXT, TEXT) TO authenticated;
