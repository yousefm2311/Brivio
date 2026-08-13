-- Migration: 20260813090100_academy_scheduling_rooms_and_notifications.sql
-- Description: Normalize rooms, centralize schedule validation, expose student/parent schedules,
-- and notify families about enrollment and schedule changes.

-- 1. Rooms catalog and schedule/session room links.
CREATE TABLE IF NOT EXISTS public.rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id UUID NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  capacity INT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT rooms_capacity_positive CHECK (capacity IS NULL OR capacity > 0),
  CONSTRAINT rooms_status_check CHECK (status IN ('active', 'inactive', 'maintenance')),
  CONSTRAINT rooms_branch_code_unique UNIQUE (branch_id, code)
);

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'rooms'
      AND policyname = 'Rooms viewable by authenticated users'
  ) THEN
    CREATE POLICY "Rooms viewable by authenticated users"
      ON public.rooms FOR SELECT TO authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'rooms'
      AND policyname = 'Rooms manageable by staff'
  ) THEN
    CREATE POLICY "Rooms manageable by staff"
      ON public.rooms FOR ALL TO authenticated
      USING (
        public.is_admin_or_super()
        OR public.has_permission('rooms.manage')
        OR public.has_permission('schedules.manage')
      )
      WITH CHECK (
        public.is_admin_or_super()
        OR public.has_permission('rooms.manage')
        OR public.has_permission('schedules.manage')
      );
  END IF;
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.rooms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rooms TO service_role;

ALTER TABLE public.schedules
  ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.class_sessions
  ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_rooms_branch_status ON public.rooms(branch_id, status);
CREATE INDEX IF NOT EXISTS idx_schedules_room_day ON public.schedules(room_id, day_of_week, status);
CREATE INDEX IF NOT EXISTS idx_schedules_group_day ON public.schedules(group_id, day_of_week, status);
CREATE INDEX IF NOT EXISTS idx_class_sessions_room_date ON public.class_sessions(room_id, session_date, status);
CREATE INDEX IF NOT EXISTS idx_class_sessions_group_date ON public.class_sessions(group_id, session_date, status);

UPDATE public.groups
SET capacity = COALESCE(capacity, max_capacity, 30),
    max_capacity = COALESCE(capacity, max_capacity, 30);

CREATE OR REPLACE FUNCTION public.sync_group_capacity_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.capacity := COALESCE(NEW.capacity, NEW.max_capacity, 30);
  NEW.max_capacity := NEW.capacity;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_group_capacity_columns_trigger ON public.groups;
CREATE TRIGGER sync_group_capacity_columns_trigger
BEFORE INSERT OR UPDATE OF capacity, max_capacity ON public.groups
FOR EACH ROW EXECUTE FUNCTION public.sync_group_capacity_columns();

DROP TRIGGER IF EXISTS update_rooms_modtime ON public.rooms;
CREATE TRIGGER update_rooms_modtime
BEFORE UPDATE ON public.rooms
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS update_schedules_modtime ON public.schedules;
CREATE TRIGGER update_schedules_modtime
BEFORE UPDATE ON public.schedules
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 2. One schedule validator used by create and update paths.
CREATE OR REPLACE FUNCTION public.validate_schedule_slot(
  p_group_id UUID,
  p_day_of_week INT,
  p_start_time TIME,
  p_end_time TIME,
  p_room_id UUID DEFAULT NULL,
  p_room_location TEXT DEFAULT NULL,
  p_exclude_schedule_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group RECORD;
  v_room RECORD;
BEGIN
  SELECT g.id, g.name, g.branch_id, g.capacity, g.status
  INTO v_group
  FROM public.groups g
  WHERE g.id = p_group_id;

  IF v_group.id IS NULL THEN
    RAISE EXCEPTION 'Group record not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('schedules.manage')
    OR public.current_teacher_assigned_to_group(p_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to manage schedule' USING ERRCODE = '42501';
  END IF;

  IF v_group.status <> 'active' THEN
    RAISE EXCEPTION 'Cannot schedule inactive group' USING ERRCODE = '22023';
  END IF;

  IF p_day_of_week < 1 OR p_day_of_week > 7 THEN
    RAISE EXCEPTION 'Invalid day of week. Use ISO values 1..7' USING ERRCODE = '22023';
  END IF;

  IF p_end_time <= p_start_time THEN
    RAISE EXCEPTION 'Schedule end_time must be strictly after start_time' USING ERRCODE = '23514';
  END IF;

  IF p_room_id IS NOT NULL THEN
    SELECT r.id, r.name, r.code, r.branch_id, r.capacity, r.status
    INTO v_room
    FROM public.rooms r
    WHERE r.id = p_room_id;

    IF v_room.id IS NULL THEN
      RAISE EXCEPTION 'Room record not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_room.status <> 'active' THEN
      RAISE EXCEPTION 'Room is not active' USING ERRCODE = '22023';
    END IF;

    IF v_room.branch_id <> v_group.branch_id THEN
      RAISE EXCEPTION 'Room branch does not match group branch' USING ERRCODE = '23514';
    END IF;

    IF v_room.capacity IS NOT NULL
       AND v_group.capacity IS NOT NULL
       AND v_group.capacity > v_room.capacity THEN
      RAISE EXCEPTION 'Group capacity exceeds room capacity' USING ERRCODE = '54000';
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.schedules s
    WHERE (p_exclude_schedule_id IS NULL OR s.id <> p_exclude_schedule_id)
      AND s.group_id = p_group_id
      AND s.day_of_week = p_day_of_week
      AND s.status = 'active'
      AND (p_start_time, p_end_time) OVERLAPS (s.start_time, s.end_time)
  ) THEN
    RAISE EXCEPTION 'Group has an overlapping active schedule slot on this day' USING ERRCODE = '23505';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.schedules s
    JOIN public.group_teachers existing_gt
      ON existing_gt.group_id = s.group_id
    JOIN public.group_teachers target_gt
      ON target_gt.teacher_id = existing_gt.teacher_id
     AND target_gt.group_id = p_group_id
    WHERE (p_exclude_schedule_id IS NULL OR s.id <> p_exclude_schedule_id)
      AND s.status = 'active'
      AND s.day_of_week = p_day_of_week
      AND COALESCE(existing_gt.effective_from, CURRENT_DATE) <= CURRENT_DATE
      AND (existing_gt.effective_to IS NULL OR existing_gt.effective_to >= CURRENT_DATE)
      AND COALESCE(target_gt.effective_from, CURRENT_DATE) <= CURRENT_DATE
      AND (target_gt.effective_to IS NULL OR target_gt.effective_to >= CURRENT_DATE)
      AND (p_start_time, p_end_time) OVERLAPS (s.start_time, s.end_time)
  ) THEN
    RAISE EXCEPTION 'Assigned teacher is scheduled in another group during this time slot' USING ERRCODE = '23505';
  END IF;

  IF p_room_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.schedules s
    JOIN public.groups g ON g.id = s.group_id
    WHERE (p_exclude_schedule_id IS NULL OR s.id <> p_exclude_schedule_id)
      AND s.room_id = p_room_id
      AND g.branch_id = v_group.branch_id
      AND s.day_of_week = p_day_of_week
      AND s.status = 'active'
      AND (p_start_time, p_end_time) OVERLAPS (s.start_time, s.end_time)
  ) THEN
    RAISE EXCEPTION 'Room is already booked during this time slot' USING ERRCODE = '23505';
  END IF;

  IF p_room_id IS NULL
     AND NULLIF(TRIM(COALESCE(p_room_location, '')), '') IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.schedules s
       JOIN public.groups g ON g.id = s.group_id
       WHERE (p_exclude_schedule_id IS NULL OR s.id <> p_exclude_schedule_id)
         AND s.day_of_week = p_day_of_week
         AND s.status = 'active'
         AND g.branch_id = v_group.branch_id
         AND LOWER(TRIM(COALESCE(s.location, ''))) = LOWER(TRIM(p_room_location))
         AND (p_start_time, p_end_time) OVERLAPS (s.start_time, s.end_time)
     )
  THEN
    RAISE EXCEPTION 'Room location is already booked during this time slot' USING ERRCODE = '23505';
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Schedule slot is valid');
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_and_create_schedule(
  p_group_id UUID,
  p_day_of_week INT,
  p_start_time TIME,
  p_end_time TIME,
  p_room_location TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_sched_id UUID;
BEGIN
  PERFORM public.validate_schedule_slot(
    p_group_id,
    p_day_of_week,
    p_start_time,
    p_end_time,
    NULL,
    p_room_location,
    NULL
  );

  INSERT INTO public.schedules (group_id, day_of_week, start_time, end_time, location, status)
  VALUES (p_group_id, p_day_of_week, p_start_time, p_end_time, NULLIF(TRIM(p_room_location), ''), 'active')
  RETURNING id INTO new_sched_id;

  RETURN jsonb_build_object(
    'success', true,
    'schedule_id', new_sched_id,
    'group_id', p_group_id,
    'message', 'Schedule created successfully'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_and_create_schedule(
  p_group_id UUID,
  p_day_of_week INT,
  p_start_time TIME,
  p_end_time TIME,
  p_room_id UUID,
  p_room_location TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_sched_id UUID;
  v_location TEXT;
BEGIN
  PERFORM public.validate_schedule_slot(
    p_group_id,
    p_day_of_week,
    p_start_time,
    p_end_time,
    p_room_id,
    p_room_location,
    NULL
  );

  SELECT COALESCE(NULLIF(TRIM(p_room_location), ''), r.name)
  INTO v_location
  FROM public.rooms r
  WHERE r.id = p_room_id;

  INSERT INTO public.schedules (group_id, day_of_week, start_time, end_time, room_id, location, status)
  VALUES (p_group_id, p_day_of_week, p_start_time, p_end_time, p_room_id, v_location, 'active')
  RETURNING id INTO new_sched_id;

  RETURN jsonb_build_object(
    'success', true,
    'schedule_id', new_sched_id,
    'group_id', p_group_id,
    'room_id', p_room_id,
    'message', 'Schedule created successfully'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.teacher_update_schedule(
  p_schedule_id UUID,
  p_day_of_week INT,
  p_start_time TIME,
  p_end_time TIME,
  p_location TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id UUID;
  v_room_id UUID;
BEGIN
  SELECT group_id, room_id
  INTO v_group_id, v_room_id
  FROM public.schedules
  WHERE id = p_schedule_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Schedule not found' USING ERRCODE = 'P0002';
  END IF;

  PERFORM public.validate_schedule_slot(
    v_group_id,
    p_day_of_week,
    p_start_time,
    p_end_time,
    v_room_id,
    p_location,
    p_schedule_id
  );

  UPDATE public.schedules
  SET day_of_week = p_day_of_week,
      start_time = p_start_time,
      end_time = p_end_time,
      location = NULLIF(TRIM(p_location), '')
  WHERE id = p_schedule_id;

  RETURN jsonb_build_object('success', true, 'schedule_id', p_schedule_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.teacher_update_schedule_with_room(
  p_schedule_id UUID,
  p_day_of_week INT,
  p_start_time TIME,
  p_end_time TIME,
  p_room_id UUID,
  p_location TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id UUID;
  v_location TEXT;
BEGIN
  SELECT group_id
  INTO v_group_id
  FROM public.schedules
  WHERE id = p_schedule_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Schedule not found' USING ERRCODE = 'P0002';
  END IF;

  PERFORM public.validate_schedule_slot(
    v_group_id,
    p_day_of_week,
    p_start_time,
    p_end_time,
    p_room_id,
    p_location,
    p_schedule_id
  );

  SELECT COALESCE(NULLIF(TRIM(p_location), ''), r.name)
  INTO v_location
  FROM public.rooms r
  WHERE r.id = p_room_id;

  UPDATE public.schedules
  SET day_of_week = p_day_of_week,
      start_time = p_start_time,
      end_time = p_end_time,
      room_id = p_room_id,
      location = v_location
  WHERE id = p_schedule_id;

  RETURN jsonb_build_object('success', true, 'schedule_id', p_schedule_id, 'room_id', p_room_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_group_sessions(
  p_group_id UUID,
  p_from_date DATE,
  p_to_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sch RECORD;
  curr_date DATE;
  gen_count INT := 0;
  sched_start TIMESTAMPTZ;
  sched_end TIMESTAMPTZ;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('groups.create')
    OR public.has_permission('schedules.manage')
    OR public.current_teacher_assigned_to_group(p_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to generate group sessions' USING ERRCODE = '42501';
  END IF;

  IF p_to_date < p_from_date OR (p_to_date - p_from_date) > 90 THEN
    RAISE EXCEPTION 'Invalid date range for session generation (max 90 days)' USING ERRCODE = '22023';
  END IF;

  FOR sch IN
    SELECT *
    FROM public.schedules
    WHERE group_id = p_group_id
      AND status = 'active'
      AND effective_from <= p_to_date
      AND (effective_to IS NULL OR effective_to >= p_from_date)
  LOOP
    curr_date := p_from_date;
    WHILE curr_date <= p_to_date LOOP
      IF EXTRACT(ISODOW FROM curr_date)::INT = sch.day_of_week
         AND curr_date >= sch.effective_from
         AND (sch.effective_to IS NULL OR curr_date <= sch.effective_to) THEN
        sched_start := (curr_date || ' ' || sch.start_time)::TIMESTAMPTZ;
        sched_end := (curr_date || ' ' || sch.end_time)::TIMESTAMPTZ;

        INSERT INTO public.class_sessions (
          group_id,
          schedule_id,
          session_date,
          scheduled_start_at,
          scheduled_end_at,
          status,
          room_id,
          location
        )
        VALUES (
          p_group_id,
          sch.id,
          curr_date,
          sched_start,
          sched_end,
          'scheduled',
          sch.room_id,
          sch.location
        )
        ON CONFLICT (group_id, session_date, scheduled_start_at) DO UPDATE SET
          schedule_id = EXCLUDED.schedule_id,
          scheduled_end_at = EXCLUDED.scheduled_end_at,
          room_id = EXCLUDED.room_id,
          location = EXCLUDED.location,
          updated_at = NOW();

        gen_count := gen_count + 1;
      END IF;
      curr_date := curr_date + 1;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'group_id', p_group_id, 'generated_count', gen_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_class_session(
  p_group_id UUID,
  p_schedule_id UUID,
  p_session_date DATE,
  p_scheduled_start_at TIMESTAMPTZ,
  p_scheduled_end_at TIMESTAMPTZ,
  p_location TEXT DEFAULT NULL
)
RETURNS public.class_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group RECORD;
  v_schedule RECORD;
  v_session public.class_sessions;
  v_room_id UUID;
  v_location TEXT;
BEGIN
  SELECT g.id, g.branch_id, g.status
  INTO v_group
  FROM public.groups g
  WHERE g.id = p_group_id;

  IF v_group.id IS NULL THEN
    RAISE EXCEPTION 'Group record not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('attendance.manage')
    OR public.has_permission('schedules.manage')
    OR public.current_teacher_assigned_to_group(p_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to create class session' USING ERRCODE = '42501';
  END IF;

  IF v_group.status <> 'active' THEN
    RAISE EXCEPTION 'Cannot create session for inactive group' USING ERRCODE = '22023';
  END IF;

  IF p_scheduled_end_at <= p_scheduled_start_at THEN
    RAISE EXCEPTION 'Session end time must be after start time' USING ERRCODE = '23514';
  END IF;

  IF p_schedule_id IS NOT NULL THEN
    SELECT *
    INTO v_schedule
    FROM public.schedules
    WHERE id = p_schedule_id
      AND group_id = p_group_id;

    IF v_schedule.id IS NULL THEN
      RAISE EXCEPTION 'Schedule does not belong to group' USING ERRCODE = '22023';
    END IF;

    v_room_id := v_schedule.room_id;
    v_location := COALESCE(NULLIF(TRIM(p_location), ''), v_schedule.location);
  ELSE
    v_location := NULLIF(TRIM(p_location), '');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.class_sessions cs
    WHERE cs.group_id = p_group_id
      AND cs.status <> 'cancelled'
      AND tstzrange(cs.scheduled_start_at, cs.scheduled_end_at, '[)')
          && tstzrange(p_scheduled_start_at, p_scheduled_end_at, '[)')
  ) THEN
    RAISE EXCEPTION 'Group already has a session in this time slot' USING ERRCODE = '23505';
  END IF;

  IF v_room_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.class_sessions cs
    JOIN public.groups g ON g.id = cs.group_id
    WHERE cs.room_id = v_room_id
      AND g.branch_id = v_group.branch_id
      AND cs.status <> 'cancelled'
      AND tstzrange(cs.scheduled_start_at, cs.scheduled_end_at, '[)')
          && tstzrange(p_scheduled_start_at, p_scheduled_end_at, '[)')
  ) THEN
    RAISE EXCEPTION 'Room is already booked for another session' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.class_sessions (
    group_id,
    schedule_id,
    session_date,
    scheduled_start_at,
    scheduled_end_at,
    status,
    room_id,
    location,
    created_by
  )
  VALUES (
    p_group_id,
    p_schedule_id,
    p_session_date,
    p_scheduled_start_at,
    p_scheduled_end_at,
    'scheduled',
    v_room_id,
    v_location,
    auth.uid()
  )
  RETURNING * INTO v_session;

  RETURN v_session;
END;
$$;

-- 3. Student and parent schedule RPCs.
CREATE OR REPLACE FUNCTION public.get_student_schedule(
  p_student_id UUID,
  p_from_date DATE DEFAULT CURRENT_DATE,
  p_to_date DATE DEFAULT (CURRENT_DATE + INTERVAL '30 days')::DATE
)
RETURNS TABLE (
  source_type TEXT,
  enrollment_id UUID,
  access_status TEXT,
  payment_status TEXT,
  group_id UUID,
  group_name TEXT,
  subject_id UUID,
  subject_name TEXT,
  branch_id UUID,
  branch_name TEXT,
  schedule_id UUID,
  class_session_id UUID,
  session_date DATE,
  day_of_week INT,
  start_time TIME,
  end_time TIME,
  scheduled_start_at TIMESTAMPTZ,
  scheduled_end_at TIMESTAMPTZ,
  status TEXT,
  room_id UUID,
  room_code TEXT,
  room_name TEXT,
  location TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID;
BEGIN
  SELECT s.id INTO v_student_id
  FROM public.students s
  WHERE s.id = p_student_id OR s.profile_id = p_student_id
  LIMIT 1;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student not found' USING ERRCODE = 'P0002';
  END IF;

  IF p_to_date < p_from_date OR (p_to_date - p_from_date) > 180 THEN
    RAISE EXCEPTION 'Invalid date range for schedule lookup (max 180 days)' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('schedules.view')
    OR public.has_permission('enrollments.view')
    OR EXISTS (SELECT 1 FROM public.students s WHERE s.id = v_student_id AND s.profile_id = auth.uid())
    OR public.current_parent_has_student(v_student_id)
    OR EXISTS (
      SELECT 1
      FROM public.enrollments e
      WHERE e.student_id = v_student_id
        AND public.current_teacher_assigned_to_group(e.group_id)
    )
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view student schedule' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH active_enrollments AS (
    SELECT e.id, e.student_id, e.group_id, e.access_status::TEXT, e.payment_status::TEXT
    FROM public.enrollments e
    WHERE e.student_id = v_student_id
      AND e.status = 'active'
      AND e.start_date <= p_to_date
      AND (e.end_date IS NULL OR e.end_date >= p_from_date)
  ),
  schedule_occurrences AS (
    SELECT
      ae.id AS enrollment_id,
      ae.access_status,
      ae.payment_status,
      g.id AS group_id,
      g.name AS group_name,
      sub.id AS subject_id,
      sub.name AS subject_name,
      b.id AS branch_id,
      b.name AS branch_name,
      sch.id AS schedule_id,
      gs.day_value::DATE AS session_date,
      sch.day_of_week,
      sch.start_time,
      sch.end_time,
      (gs.day_value::DATE || ' ' || sch.start_time)::TIMESTAMPTZ AS scheduled_start_at,
      (gs.day_value::DATE || ' ' || sch.end_time)::TIMESTAMPTZ AS scheduled_end_at,
      sch.status,
      sch.room_id,
      r.code AS room_code,
      r.name AS room_name,
      COALESCE(sch.location, r.name) AS location
    FROM active_enrollments ae
    JOIN public.groups g ON g.id = ae.group_id
    JOIN public.subjects sub ON sub.id = g.subject_id
    JOIN public.branches b ON b.id = g.branch_id
    JOIN public.schedules sch ON sch.group_id = g.id AND sch.status = 'active'
    CROSS JOIN generate_series(p_from_date, p_to_date, INTERVAL '1 day') AS gs(day_value)
    LEFT JOIN public.rooms r ON r.id = sch.room_id
    WHERE EXTRACT(ISODOW FROM gs.day_value)::INT = sch.day_of_week
      AND gs.day_value::DATE >= sch.effective_from
      AND (sch.effective_to IS NULL OR gs.day_value::DATE <= sch.effective_to)
  ),
  session_rows AS (
    SELECT
      ae.id AS enrollment_id,
      ae.access_status,
      ae.payment_status,
      g.id AS group_id,
      g.name AS group_name,
      sub.id AS subject_id,
      sub.name AS subject_name,
      b.id AS branch_id,
      b.name AS branch_name,
      cs.schedule_id,
      cs.id AS class_session_id,
      cs.session_date,
      EXTRACT(ISODOW FROM cs.session_date)::INT AS day_of_week,
      cs.scheduled_start_at::TIME AS start_time,
      cs.scheduled_end_at::TIME AS end_time,
      cs.scheduled_start_at,
      cs.scheduled_end_at,
      cs.status,
      cs.room_id,
      r.code AS room_code,
      r.name AS room_name,
      COALESCE(cs.location, r.name) AS location
    FROM active_enrollments ae
    JOIN public.groups g ON g.id = ae.group_id
    JOIN public.subjects sub ON sub.id = g.subject_id
    JOIN public.branches b ON b.id = g.branch_id
    JOIN public.class_sessions cs ON cs.group_id = g.id
    LEFT JOIN public.rooms r ON r.id = cs.room_id
    WHERE cs.session_date BETWEEN p_from_date AND p_to_date
  )
  SELECT
    'schedule'::TEXT,
    so.enrollment_id,
    so.access_status,
    so.payment_status,
    so.group_id,
    so.group_name,
    so.subject_id,
    so.subject_name,
    so.branch_id,
    so.branch_name,
    so.schedule_id,
    NULL::UUID,
    so.session_date,
    so.day_of_week,
    so.start_time,
    so.end_time,
    so.scheduled_start_at,
    so.scheduled_end_at,
    so.status,
    so.room_id,
    so.room_code,
    so.room_name,
    so.location
  FROM schedule_occurrences so
  UNION ALL
  SELECT
    'session'::TEXT,
    sr.enrollment_id,
    sr.access_status,
    sr.payment_status,
    sr.group_id,
    sr.group_name,
    sr.subject_id,
    sr.subject_name,
    sr.branch_id,
    sr.branch_name,
    sr.schedule_id,
    sr.class_session_id,
    sr.session_date,
    sr.day_of_week,
    sr.start_time,
    sr.end_time,
    sr.scheduled_start_at,
    sr.scheduled_end_at,
    sr.status,
    sr.room_id,
    sr.room_code,
    sr.room_name,
    sr.location
  FROM session_rows sr
  ORDER BY 13, 15, 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_parent_child_schedule(
  p_student_id UUID,
  p_from_date DATE DEFAULT CURRENT_DATE,
  p_to_date DATE DEFAULT (CURRENT_DATE + INTERVAL '30 days')::DATE
)
RETURNS TABLE (
  source_type TEXT,
  enrollment_id UUID,
  access_status TEXT,
  payment_status TEXT,
  group_id UUID,
  group_name TEXT,
  subject_id UUID,
  subject_name TEXT,
  branch_id UUID,
  branch_name TEXT,
  schedule_id UUID,
  class_session_id UUID,
  session_date DATE,
  day_of_week INT,
  start_time TIME,
  end_time TIME,
  scheduled_start_at TIMESTAMPTZ,
  scheduled_end_at TIMESTAMPTZ,
  status TEXT,
  room_id UUID,
  room_code TEXT,
  room_name TEXT,
  location TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID;
BEGIN
  SELECT s.id INTO v_student_id
  FROM public.students s
  WHERE s.id = p_student_id OR s.profile_id = p_student_id
  LIMIT 1;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('schedules.view')
    OR public.current_parent_has_student(v_student_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view child schedule' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.get_student_schedule(v_student_id, p_from_date, p_to_date);
END;
$$;

DROP FUNCTION IF EXISTS public.get_current_student_lessons();
CREATE OR REPLACE FUNCTION public.get_current_student_lessons()
RETURNS TABLE (
  lesson_id UUID,
  lesson_title TEXT,
  group_id UUID,
  subject_name TEXT,
  unit_name TEXT,
  progress_percentage NUMERIC,
  estimated_minutes INT,
  last_page INT,
  total_pages INT,
  has_pdf BOOLEAN,
  has_code_playground BOOLEAN,
  pdf_bucket TEXT,
  pdf_object_path TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (g.id, l.id)
    l.id AS lesson_id,
    COALESCE(l.title, 'Untitled lesson')::TEXT AS lesson_title,
    g.id AS group_id,
    COALESCE(s.name, 'Assigned subject')::TEXT AS subject_name,
    COALESCE(u.name, 'Unit')::TEXT AS unit_name,
    COALESCE(lp.progress_percentage, 0)::NUMERIC AS progress_percentage,
    COALESCE(l.estimated_duration_minutes, 0)::INT AS estimated_minutes,
    GREATEST(1, COALESCE(CASE WHEN COALESCE(lp.last_position, '') ~ '^[0-9]+$' THEN lp.last_position::INT ELSE NULL END, 1))::INT AS last_page,
    GREATEST(1, COALESCE(NULLIF((lr.metadata->>'page_count'), '')::INT, 1))::INT AS total_pages,
    (lr.id IS NOT NULL)::BOOLEAN AS has_pdf,
    (l.lesson_type::TEXT = 'programming')::BOOLEAN AS has_code_playground,
    lr.bucket::TEXT AS pdf_bucket,
    lr.object_path::TEXT AS pdf_object_path
  FROM public.enrollments e
  JOIN public.groups g ON g.id = e.group_id
  JOIN public.semesters sem ON sem.subject_id = g.subject_id
  JOIN public.units u ON u.semester_id = sem.id
  JOIN public.lessons l ON l.unit_id = u.id
  LEFT JOIN public.subjects s ON s.id = g.subject_id
  LEFT JOIN public.lesson_progress lp ON lp.lesson_id = l.id AND lp.student_id = v_student_id
  LEFT JOIN public.lesson_resources lr ON lr.lesson_id = l.id AND lr.resource_type = 'pdf'
  WHERE e.student_id = v_student_id
    AND public.enrollment_has_learning_access(e.id)
    AND g.status = 'active'
    AND u.status = 'active'
    AND l.status = 'published'
  ORDER BY g.id, l.id, sem.order_number, u.order_number, l.order_number, lr.order_number;
END;
$$;

DROP FUNCTION IF EXISTS public.get_accessible_student_lessons(UUID);
CREATE OR REPLACE FUNCTION public.get_accessible_student_lessons(p_student_id UUID)
RETURNS TABLE (
  lesson_id UUID,
  lesson_title TEXT,
  group_id UUID,
  subject_name TEXT,
  unit_name TEXT,
  progress_percentage NUMERIC,
  estimated_minutes INT,
  last_page INT,
  total_pages INT,
  has_pdf BOOLEAN,
  has_code_playground BOOLEAN,
  pdf_bucket TEXT,
  pdf_object_path TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_student_id IS NULL THEN
    RAISE EXCEPTION 'Student id is required' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    p_student_id = public.current_student_id()
    OR public.current_parent_has_student(p_student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view student lessons' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (g.id, l.id)
    l.id AS lesson_id,
    COALESCE(l.title, 'Untitled lesson')::TEXT AS lesson_title,
    g.id AS group_id,
    COALESCE(s.name, 'Assigned subject')::TEXT AS subject_name,
    COALESCE(u.name, 'Unit')::TEXT AS unit_name,
    COALESCE(lp.progress_percentage, 0)::NUMERIC AS progress_percentage,
    COALESCE(l.estimated_duration_minutes, 0)::INT AS estimated_minutes,
    GREATEST(1, COALESCE(CASE WHEN COALESCE(lp.last_position, '') ~ '^[0-9]+$' THEN lp.last_position::INT ELSE NULL END, 1))::INT AS last_page,
    GREATEST(1, COALESCE(NULLIF((lr.metadata->>'page_count'), '')::INT, 1))::INT AS total_pages,
    (lr.id IS NOT NULL)::BOOLEAN AS has_pdf,
    (l.lesson_type::TEXT = 'programming')::BOOLEAN AS has_code_playground,
    lr.bucket::TEXT AS pdf_bucket,
    lr.object_path::TEXT AS pdf_object_path
  FROM public.enrollments e
  JOIN public.groups g ON g.id = e.group_id
  JOIN public.semesters sem ON sem.subject_id = g.subject_id
  JOIN public.units u ON u.semester_id = sem.id
  JOIN public.lessons l ON l.unit_id = u.id
  LEFT JOIN public.subjects s ON s.id = g.subject_id
  LEFT JOIN public.lesson_progress lp ON lp.lesson_id = l.id AND lp.student_id = p_student_id
  LEFT JOIN public.lesson_resources lr ON lr.lesson_id = l.id AND lr.resource_type = 'pdf'
  WHERE e.student_id = p_student_id
    AND public.enrollment_has_learning_access(e.id)
    AND g.status = 'active'
    AND u.status = 'active'
    AND l.status = 'published'
  ORDER BY g.id, l.id, sem.order_number, u.order_number, l.order_number, lr.order_number;
END;
$$;

-- 4. Family notification helpers and triggers.
CREATE OR REPLACE FUNCTION public.notify_student_and_parents(
  p_student_id UUID,
  p_title TEXT,
  p_message TEXT,
  p_type TEXT,
  p_reference_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_profile_id UUID;
  parent_rec RECORD;
BEGIN
  SELECT profile_id INTO v_student_profile_id
  FROM public.students
  WHERE id = p_student_id;

  IF v_student_profile_id IS NOT NULL THEN
    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
    VALUES (v_student_profile_id, p_title, p_message, p_type, p_reference_id);
  END IF;

  FOR parent_rec IN
    SELECT p.profile_id
    FROM public.parent_students ps
    JOIN public.parents p ON p.id = ps.parent_id
    WHERE ps.student_id = p_student_id
      AND p.status = 'active'
  LOOP
    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
    VALUES (parent_rec.profile_id, p_title, p_message, p_type, p_reference_id);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_enrollment_schedule_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_name TEXT;
BEGIN
  IF TG_OP = 'INSERT'
     OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'active') THEN
    SELECT name INTO v_group_name
    FROM public.groups
    WHERE id = NEW.group_id;

    PERFORM public.notify_student_and_parents(
      NEW.student_id,
      'Group enrollment confirmed',
      'Enrollment in ' || COALESCE(v_group_name, 'your group') || ' is now active.',
      'enrollment',
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_enrollment_schedule_event_trigger ON public.enrollments;
CREATE TRIGGER notify_enrollment_schedule_event_trigger
AFTER INSERT OR UPDATE OF status ON public.enrollments
FOR EACH ROW EXECUTE FUNCTION public.notify_enrollment_schedule_event();

CREATE OR REPLACE FUNCTION public.notify_group_schedule_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id UUID;
  v_group_name TEXT;
  v_title TEXT;
  v_message TEXT;
  v_reference_id UUID;
  enr RECORD;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_group_id := OLD.group_id;
    v_reference_id := OLD.id;
    v_title := 'Group schedule removed';
  ELSE
    v_group_id := NEW.group_id;
    v_reference_id := NEW.id;
    v_title := CASE WHEN TG_OP = 'INSERT' THEN 'New group schedule' ELSE 'Group schedule changed' END;
  END IF;

  SELECT name INTO v_group_name
  FROM public.groups
  WHERE id = v_group_id;

  v_message := COALESCE(v_group_name, 'Your group') || ' schedule was updated. Please check your timetable.';

  FOR enr IN
    SELECT student_id
    FROM public.enrollments
    WHERE group_id = v_group_id
      AND status = 'active'
  LOOP
    PERFORM public.notify_student_and_parents(
      enr.student_id,
      v_title,
      v_message,
      'schedule',
      v_reference_id
    );
  END LOOP;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_group_schedule_insert_trigger ON public.schedules;
CREATE TRIGGER notify_group_schedule_insert_trigger
AFTER INSERT ON public.schedules
FOR EACH ROW EXECUTE FUNCTION public.notify_group_schedule_event();

DROP TRIGGER IF EXISTS notify_group_schedule_update_trigger ON public.schedules;
CREATE TRIGGER notify_group_schedule_update_trigger
AFTER UPDATE OF day_of_week, start_time, end_time, room_id, location, status, effective_from, effective_to ON public.schedules
FOR EACH ROW
WHEN (
  OLD.day_of_week IS DISTINCT FROM NEW.day_of_week
  OR OLD.start_time IS DISTINCT FROM NEW.start_time
  OR OLD.end_time IS DISTINCT FROM NEW.end_time
  OR OLD.room_id IS DISTINCT FROM NEW.room_id
  OR OLD.location IS DISTINCT FROM NEW.location
  OR OLD.status IS DISTINCT FROM NEW.status
  OR OLD.effective_from IS DISTINCT FROM NEW.effective_from
  OR OLD.effective_to IS DISTINCT FROM NEW.effective_to
)
EXECUTE FUNCTION public.notify_group_schedule_event();

DROP TRIGGER IF EXISTS notify_group_schedule_delete_trigger ON public.schedules;
CREATE TRIGGER notify_group_schedule_delete_trigger
AFTER DELETE ON public.schedules
FOR EACH ROW EXECUTE FUNCTION public.notify_group_schedule_event();

REVOKE EXECUTE ON FUNCTION public.validate_schedule_slot(UUID, INT, TIME, TIME, UUID, TEXT, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.validate_and_create_schedule(UUID, INT, TIME, TIME, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.validate_and_create_schedule(UUID, INT, TIME, TIME, UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.teacher_update_schedule(UUID, INT, TIME, TIME, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.teacher_update_schedule_with_room(UUID, INT, TIME, TIME, UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.generate_group_sessions(UUID, DATE, DATE) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_class_session(UUID, UUID, DATE, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_student_schedule(UUID, DATE, DATE) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_parent_child_schedule(UUID, DATE, DATE) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_current_student_lessons() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_accessible_student_lessons(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_student_and_parents(UUID, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.validate_schedule_slot(UUID, INT, TIME, TIME, UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_and_create_schedule(UUID, INT, TIME, TIME, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_and_create_schedule(UUID, INT, TIME, TIME, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teacher_update_schedule(UUID, INT, TIME, TIME, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teacher_update_schedule_with_room(UUID, INT, TIME, TIME, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_group_sessions(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_class_session(UUID, UUID, DATE, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_student_schedule(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_parent_child_schedule(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_student_lessons() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_accessible_student_lessons(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.notify_student_and_parents(UUID, TEXT, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.notify_student_and_parents(UUID, TEXT, TEXT, TEXT, UUID) TO service_role;

NOTIFY pgrst, 'reload schema';
