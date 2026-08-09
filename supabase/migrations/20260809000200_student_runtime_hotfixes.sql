-- Runtime hotfixes for student portal lessons and attendance payload compatibility.

ALTER TABLE public.lesson_resources
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS max_capacity INT;

ALTER TABLE public.units
  ADD COLUMN IF NOT EXISTS subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS order_number INT NOT NULL DEFAULT 1;

ALTER TABLE public.subjects
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

ALTER TABLE public.lessons
  ADD COLUMN IF NOT EXISTS estimated_duration_minutes INT,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS order_number INT NOT NULL DEFAULT 1;

UPDATE public.groups
SET max_capacity = COALESCE(max_capacity, capacity)
WHERE max_capacity IS NULL;

DROP FUNCTION IF EXISTS public.mark_session_attendance(UUID, JSONB);
CREATE OR REPLACE FUNCTION public.mark_session_attendance(
  p_session_id UUID,
  p_records JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
    RAISE EXCEPTION 'Class session not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('attendance.mark')
    OR public.current_teacher_assigned_to_group(cs.group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to mark attendance for this class session'
      USING ERRCODE = '42501';
  END IF;

  FOR rec IN
    SELECT *
    FROM jsonb_to_recordset(p_records) AS x(
      student_id UUID,
      attendance_status TEXT,
      status TEXT,
      arrival_at TIMESTAMPTZ,
      notes TEXT
    )
  LOOP
    s_id := rec.student_id;
    st := COALESCE(NULLIF(rec.attendance_status, ''), NULLIF(rec.status, ''), 'present');
    arr := rec.arrival_at;
    nt := rec.notes;

    IF st NOT IN ('present', 'absent', 'late', 'excused') THEN
      RAISE EXCEPTION 'Invalid attendance status: %', st USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.enrollments
      WHERE group_id = cs.group_id
        AND student_id = s_id
        AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'Student % is not actively enrolled in session group', s_id
        USING ERRCODE = '22000';
    END IF;

    INSERT INTO public.attendance_records (
      class_session_id,
      student_id,
      attendance_status,
      marked_by,
      marked_at,
      arrival_at,
      notes
    ) VALUES (
      p_session_id,
      s_id,
      st,
      auth.uid(),
      NOW(),
      arr,
      nt
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

  RETURN jsonb_build_object(
    'success', true,
    'session_id', p_session_id,
    'marked_count', marked_count
  );
END;
$$;

DROP FUNCTION IF EXISTS public.get_current_student_lessons();
CREATE OR REPLACE FUNCTION public.get_current_student_lessons()
RETURNS TABLE (
  lesson_id UUID,
  lesson_title TEXT,
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
  SELECT DISTINCT ON (l.id)
    l.id AS lesson_id,
    COALESCE(l.title, 'Untitled lesson')::TEXT AS lesson_title,
    COALESCE(s.name, 'Assigned subject')::TEXT AS subject_name,
    COALESCE(u.name, 'Unit')::TEXT AS unit_name,
    COALESCE(lp.progress_percentage, 0)::NUMERIC AS progress_percentage,
    COALESCE(l.estimated_duration_minutes, 0)::INT AS estimated_minutes,
    GREATEST(
      1,
      COALESCE(
        CASE
          WHEN COALESCE(lp.last_position, '') ~ '^[0-9]+$'
            THEN lp.last_position::INT
          ELSE NULL
        END,
        1
      )
    )::INT AS last_page,
    GREATEST(
      1,
      COALESCE(NULLIF((lr.metadata->>'page_count'), '')::INT, 1)
    )::INT AS total_pages,
    (lr.id IS NOT NULL)::BOOLEAN AS has_pdf,
    (l.lesson_type::TEXT = 'programming')::BOOLEAN AS has_code_playground,
    lr.bucket::TEXT AS pdf_bucket,
    lr.object_path::TEXT AS pdf_object_path
  FROM public.enrollments e
  JOIN public.groups g ON g.id = e.group_id
  JOIN public.units u ON u.subject_id = g.subject_id
  JOIN public.lessons l ON l.unit_id = u.id
  LEFT JOIN public.subjects s ON s.id = g.subject_id
  LEFT JOIN public.lesson_progress lp
    ON lp.lesson_id = l.id
   AND lp.student_id = v_student_id
  LEFT JOIN public.lesson_resources lr
    ON lr.lesson_id = l.id
   AND lr.resource_type = 'pdf'
  WHERE e.student_id = v_student_id
    AND e.status = 'active'
    AND g.status = 'active'
    AND u.status = 'active'
    AND l.status = 'published'
  ORDER BY l.id, u.order_number, l.order_number, lr.order_number;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_session_attendance(UUID, JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_current_student_lessons() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_session_attendance(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_student_lessons() TO authenticated;

DROP FUNCTION IF EXISTS public.get_student_published_session_boards();
CREATE OR REPLACE FUNCTION public.get_student_published_session_boards()
RETURNS TABLE (
  id UUID,
  title TEXT,
  group_name TEXT,
  session_date DATE,
  updated_at TIMESTAMPTZ,
  board_data JSONB
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
  SELECT DISTINCT
    b.id,
    COALESCE(
      NULLIF(trim(cs.location), ''),
      'Session board - ' || to_char(cs.session_date, 'YYYY-MM-DD')
    )::TEXT AS title,
    trim(COALESCE(g.name, 'Group') || ' ' || COALESCE(g.code, ''))::TEXT AS group_name,
    cs.session_date,
    b.updated_at,
    COALESCE(b.board_data, '{}'::jsonb) AS board_data
  FROM public.class_session_boards b
  JOIN public.class_sessions cs ON cs.id = b.class_session_id
  JOIN public.groups g ON g.id = b.group_id
  JOIN public.attendance_records ar ON ar.class_session_id = b.class_session_id
  WHERE b.is_published = true
    AND ar.student_id = v_student_id
    AND ar.attendance_status IN ('present', 'late')
  ORDER BY b.updated_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_student_published_session_boards() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_student_published_session_boards() TO authenticated;

NOTIFY pgrst, 'reload schema';
