-- Migration: 20260809000700_parent_reports_runtime.sql
-- Description: Parent-safe access to a linked child's published lessons.

DROP FUNCTION IF EXISTS public.get_accessible_student_lessons(UUID);
CREATE OR REPLACE FUNCTION public.get_accessible_student_lessons(
  p_student_id UUID
)
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
BEGIN
  IF p_student_id IS NULL THEN
    RAISE EXCEPTION 'Student id is required' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    p_student_id = public.current_student_id()
    OR public.is_parent_of_student(auth.uid(), p_student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view student lessons'
      USING ERRCODE = '42501';
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
   AND lp.student_id = p_student_id
  LEFT JOIN public.lesson_resources lr
    ON lr.lesson_id = l.id
   AND lr.resource_type = 'pdf'
  WHERE e.student_id = p_student_id
    AND e.status = 'active'
    AND g.status = 'active'
    AND u.status = 'active'
    AND l.status = 'published'
  ORDER BY l.id, u.order_number, l.order_number, lr.order_number;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_accessible_student_lessons(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_accessible_student_lessons(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
