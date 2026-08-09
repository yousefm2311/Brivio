-- Migration: 20260809000500_teacher_analytics_runtime.sql
-- Description: Teacher group analytics for attendance, homework queue, and exam performance.

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
    LEFT JOIN public.group_teachers gt ON gt.group_id = g.id
    WHERE g.status = 'active'
      AND (g.teacher_id = v_teacher_id OR gt.teacher_id = v_teacher_id)
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

REVOKE EXECUTE ON FUNCTION public.get_current_teacher_group_analytics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_teacher_group_analytics() TO authenticated;

NOTIFY pgrst, 'reload schema';
