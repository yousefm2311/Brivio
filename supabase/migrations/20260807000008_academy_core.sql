-- Migration: 20260807000008_academy_core.sql
-- Description: Academy Core Infrastructure (Group Capacity Column, Atomic Concurrency-Safe Enrollment, Schedule Conflict RPCs, and Dashboard Aggregates)

-- 0. Add max_capacity column to public.groups
ALTER TABLE public.groups
    ADD COLUMN IF NOT EXISTS max_capacity INT DEFAULT NULL;

-- 1. Atomic Concurrency-Safe Enrollment RPC Function
-- Prevents capacity overbooking race conditions via PostgreSQL FOR UPDATE row locking
CREATE OR REPLACE FUNCTION public.enroll_student_in_group(
    p_student_id UUID,
    p_group_id UUID
)
RETURNS JSONB AS $$
DECLARE
    g_rec RECORD;
    current_active_count INT;
    s_status text;
BEGIN
    -- Verify caller authorization
    IF NOT (public.is_admin_or_super() OR public.has_permission('enrollments.view')) THEN
        RAISE EXCEPTION 'Unauthorized to enroll student' USING ERRCODE = '42501';
    END IF;

    -- Verify student active status
    SELECT status INTO s_status FROM public.students WHERE id = p_student_id;
    IF s_status IS NULL THEN
        RAISE EXCEPTION 'Student record not found' USING ERRCODE = 'P0002';
    END IF;
    IF s_status != 'active' THEN
        RAISE EXCEPTION 'Cannot enroll inactive student' USING ERRCODE = '22023';
    END IF;

    -- Lock group row for capacity concurrency check
    SELECT id, max_capacity, status INTO g_rec
    FROM public.groups
    WHERE id = p_group_id
    FOR UPDATE;

    IF g_rec IS NULL THEN
        RAISE EXCEPTION 'Group record not found' USING ERRCODE = 'P0002';
    END IF;

    IF g_rec.status != 'active' THEN
        RAISE EXCEPTION 'Cannot enroll into inactive group' USING ERRCODE = '22023';
    END IF;

    -- Count active enrollments
    SELECT COUNT(*)::int INTO current_active_count
    FROM public.enrollments
    WHERE group_id = p_group_id AND status = 'active';

    IF g_rec.max_capacity IS NOT NULL AND current_active_count >= g_rec.max_capacity THEN
        RAISE EXCEPTION 'Group capacity exceeded (max: %)', g_rec.max_capacity USING ERRCODE = '54000';
    END IF;

    -- Check for duplicate active enrollment
    IF EXISTS (
        SELECT 1 FROM public.enrollments
        WHERE student_id = p_student_id AND group_id = p_group_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Student is already actively enrolled in this group' USING ERRCODE = '23505';
    END IF;

    -- Create enrollment record
    INSERT INTO public.enrollments (student_id, group_id, status, enrolled_at)
    VALUES (p_student_id, p_group_id, 'active', NOW());

    RETURN jsonb_build_object(
        'success', true,
        'student_id', p_student_id,
        'group_id', p_group_id,
        'enrolled_at', NOW(),
        'message', 'Student enrolled successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.enroll_student_in_group(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enroll_student_in_group(UUID, UUID) TO authenticated;

-- 2. Schedule Conflict Validation & Creation RPC
CREATE OR REPLACE FUNCTION public.validate_and_create_schedule(
    p_group_id UUID,
    p_day_of_week INT,
    p_start_time TIME,
    p_end_time TIME,
    p_room_location TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    t_id UUID;
    new_sched_id UUID;
BEGIN
    -- Verify time order boundary
    IF p_end_time <= p_start_time THEN
        RAISE EXCEPTION 'Schedule end_time must be strictly after start_time' USING ERRCODE = '23514';
    END IF;

    -- Check Group Schedule Overlap
    IF EXISTS (
        SELECT 1 FROM public.schedules
        WHERE group_id = p_group_id
          AND day_of_week = p_day_of_week
          AND status = 'active'
          AND (p_start_time, p_end_time) OVERLAPS (start_time, end_time)
    ) THEN
        RAISE EXCEPTION 'Group has an overlapping active schedule slot on this day' USING ERRCODE = '23505';
    END IF;

    -- Resolve primary active teacher assigned to group
    SELECT teacher_id INTO t_id
    FROM public.group_teachers
    WHERE group_id = p_group_id AND is_primary = true AND effective_from <= CURRENT_DATE AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
    LIMIT 1;

    -- Check Teacher Schedule Overlap
    IF t_id IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.schedules s
            JOIN public.group_teachers gt ON gt.group_id = s.group_id
            WHERE gt.teacher_id = t_id
              AND s.day_of_week = p_day_of_week
              AND s.status = 'active'
              AND (p_start_time, p_end_time) OVERLAPS (s.start_time, s.end_time)
        ) THEN
            RAISE EXCEPTION 'Assigned primary teacher is scheduled in another group during this time slot' USING ERRCODE = '23505';
        END IF;
    END IF;

    -- Check Room Location Overlap (if location specified)
    IF p_room_location IS NOT NULL AND TRIM(p_room_location) != '' THEN
        IF EXISTS (
            SELECT 1 FROM public.schedules
            WHERE location = p_room_location
              AND day_of_week = p_day_of_week
              AND status = 'active'
              AND (p_start_time, p_end_time) OVERLAPS (start_time, end_time)
        ) THEN
            RAISE EXCEPTION 'Room location "%" is already booked during this time slot', p_room_location USING ERRCODE = '23505';
        END IF;
    END IF;

    -- Create schedule entry
    new_sched_id := gen_random_uuid();
    INSERT INTO public.schedules (id, group_id, day_of_week, start_time, end_time, location, status)
    VALUES (new_sched_id, p_group_id, p_day_of_week, p_start_time, p_end_time, p_room_location, 'active');

    RETURN jsonb_build_object(
        'success', true,
        'schedule_id', new_sched_id,
        'group_id', p_group_id,
        'message', 'Schedule created successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.validate_and_create_schedule(UUID, INT, TIME, TIME, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_and_create_schedule(UUID, INT, TIME, TIME, TEXT) TO authenticated;

-- 3. Academy Core Dashboard Aggregate Summary RPC
CREATE OR REPLACE FUNCTION public.get_academy_core_summary()
RETURNS JSONB AS $$
DECLARE
    b_count INT;
    s_count INT;
    t_count INT;
    sub_count INT;
    g_count INT;
    today_sched_count INT;
    result JSONB;
BEGIN
    SELECT COUNT(*)::int INTO b_count FROM public.branches WHERE status = 'active';
    SELECT COUNT(*)::int INTO s_count FROM public.students WHERE status = 'active';
    SELECT COUNT(*)::int INTO t_count FROM public.teachers;
    SELECT COUNT(*)::int INTO sub_count FROM public.subjects WHERE status = 'active';
    SELECT COUNT(*)::int INTO g_count FROM public.groups WHERE status = 'active';
    SELECT COUNT(*)::int INTO today_sched_count FROM public.schedules WHERE day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::int AND status = 'active';

    result := jsonb_build_object(
        'active_branches', b_count,
        'active_students', s_count,
        'active_teachers', t_count,
        'active_subjects', sub_count,
        'active_groups', g_count,
        'today_scheduled_classes', today_sched_count
    );

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.get_academy_core_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_academy_core_summary() TO authenticated;
