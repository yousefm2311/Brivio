-- Migration: 20260809001600_runtime_logic_fixes.sql
-- Description: Correct runtime logic for teacher analytics, audit trigger compatibility, and payment-gated student groups.

DROP FUNCTION IF EXISTS public.get_current_teacher_group_analytics();
CREATE OR REPLACE FUNCTION public.get_current_teacher_group_analytics()
RETURNS TABLE (
  group_id UUID,
  group_name TEXT,
  group_code TEXT,
  student_count INT,
  completed_sessions INT,
  attendance_rate NUMERIC,
  absent_count INT,
  pending_homework_count INT,
  average_exam_score NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID := public.current_teacher_id();
BEGIN
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Teacher profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH assigned_groups AS (
    SELECT DISTINCT g.id, g.name, g.code
    FROM public.groups g
    JOIN public.group_teachers gt ON gt.group_id = g.id
    WHERE g.status = 'active'
      AND gt.teacher_id = v_teacher_id
  ),
  enrollment_counts AS (
    SELECT e.group_id, COUNT(*)::INT AS student_count
    FROM public.enrollments e
    JOIN assigned_groups ag ON ag.id = e.group_id
    WHERE e.status = 'active'
    GROUP BY e.group_id
  ),
  session_counts AS (
    SELECT cs.group_id, COUNT(*)::INT AS completed_sessions
    FROM public.class_sessions cs
    JOIN assigned_groups ag ON ag.id = cs.group_id
    WHERE cs.status = 'completed'
    GROUP BY cs.group_id
  ),
  attendance_stats AS (
    SELECT
      cs.group_id,
      COUNT(ar.id)::INT AS marked_count,
      COUNT(ar.id) FILTER (WHERE ar.attendance_status = 'absent')::INT AS absent_count,
      COUNT(ar.id) FILTER (
        WHERE ar.attendance_status IN ('present', 'late', 'excused')
      )::INT AS attended_count
    FROM public.class_sessions cs
    JOIN assigned_groups ag ON ag.id = cs.group_id
    LEFT JOIN public.attendance_records ar ON ar.class_session_id = cs.id
    GROUP BY cs.group_id
  ),
  homework_stats AS (
    SELECT
      h.group_id,
      COUNT(*) FILTER (
        WHERE h.status = 'published'
          AND e.status = 'active'
          AND (hs.id IS NULL OR hs.status <> 'graded')
      )::INT AS pending_homework_count
    FROM public.homework h
    JOIN assigned_groups ag ON ag.id = h.group_id
    LEFT JOIN public.enrollments e ON e.group_id = h.group_id
    LEFT JOIN public.homework_submissions hs
      ON hs.homework_id = h.id
     AND hs.student_id = e.student_id
    GROUP BY h.group_id
  ),
  exam_stats AS (
    SELECT
      ex.group_id,
      ROUND(AVG((ea.score / NULLIF(ea.max_score, 0)) * 100), 1) AS average_exam_score
    FROM public.exams ex
    JOIN assigned_groups ag ON ag.id = ex.group_id
    JOIN public.exam_attempts ea ON ea.exam_id = ex.id
    WHERE ea.score IS NOT NULL
      AND ea.max_score > 0
      AND ea.status IN ('submitted', 'graded')
    GROUP BY ex.group_id
  )
  SELECT
    ag.id AS group_id,
    ag.name::TEXT AS group_name,
    ag.code::TEXT AS group_code,
    COALESCE(ec.student_count, 0)::INT AS student_count,
    COALESCE(sc.completed_sessions, 0)::INT AS completed_sessions,
    CASE
      WHEN COALESCE(att.marked_count, 0) = 0 THEN 0::NUMERIC
      ELSE ROUND((att.attended_count::NUMERIC / att.marked_count::NUMERIC) * 100, 1)
    END AS attendance_rate,
    COALESCE(att.absent_count, 0)::INT AS absent_count,
    COALESCE(hw.pending_homework_count, 0)::INT AS pending_homework_count,
    COALESCE(exs.average_exam_score, 0)::NUMERIC AS average_exam_score
  FROM assigned_groups ag
  LEFT JOIN enrollment_counts ec ON ec.group_id = ag.id
  LEFT JOIN session_counts sc ON sc.group_id = ag.id
  LEFT JOIN attendance_stats att ON att.group_id = ag.id
  LEFT JOIN homework_stats hw ON hw.group_id = ag.id
  LEFT JOIN exam_stats exs ON exs.group_id = ag.id
  ORDER BY ag.name, ag.code;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_current_teacher_group_analytics() TO authenticated;

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  table_name TEXT NOT NULL,
  record_id UUID,
  action TEXT NOT NULL,
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS table_name TEXT,
  ADD COLUMN IF NOT EXISTS record_id UUID,
  ADD COLUMN IF NOT EXISTS action TEXT,
  ADD COLUMN IF NOT EXISTS old_data JSONB,
  ADD COLUMN IF NOT EXISTS new_data JSONB,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'audit_logs'
      AND column_name = 'actor_user_id'
  ) THEN
    EXECUTE 'UPDATE public.audit_logs SET actor_id = actor_user_id WHERE actor_id IS NULL';
  END IF;
END;
$$;

UPDATE public.audit_logs
SET action = lower(action)
WHERE action IS NOT NULL;

ALTER TABLE public.audit_logs
  ALTER COLUMN table_name SET NOT NULL,
  ALTER COLUMN action SET NOT NULL,
  DROP CONSTRAINT IF EXISTS audit_logs_action_check,
  ADD CONSTRAINT audit_logs_action_check
    CHECK (action IN ('insert', 'update', 'delete'));

CREATE OR REPLACE FUNCTION public.write_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_record_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_record_id := NULLIF(to_jsonb(OLD)->>'id', '')::UUID;
  ELSE
    v_record_id := NULLIF(to_jsonb(NEW)->>'id', '')::UUID;
  END IF;

  INSERT INTO public.audit_logs (
    actor_id,
    table_name,
    record_id,
    action,
    old_data,
    new_data
  )
  VALUES (
    auth.uid(),
    TG_TABLE_NAME,
    v_record_id,
    lower(TG_OP),
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP FUNCTION IF EXISTS public.get_student_groups(UUID);
CREATE OR REPLACE FUNCTION public.get_student_groups(p_student_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  code TEXT,
  subject_id UUID,
  branch_id UUID,
  max_capacity INT,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('enrollments.view')
    OR public.has_permission('enrollments.manage')
    OR p_student_id = public.current_student_id()
    OR public.current_parent_has_student(p_student_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view student groups' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT DISTINCT
    g.id,
    COALESCE(g.name, 'Group')::TEXT AS name,
    COALESCE(g.code, '')::TEXT AS code,
    g.subject_id,
    g.branch_id,
    COALESCE(g.max_capacity, g.capacity)::INT AS max_capacity,
    COALESCE(g.status, 'active')::TEXT AS status
  FROM public.enrollments e
  JOIN public.groups g ON g.id = e.group_id
  WHERE e.student_id = p_student_id
    AND public.enrollment_has_learning_access(e.id)
    AND g.status = 'active'
  ORDER BY 2;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_groups(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
