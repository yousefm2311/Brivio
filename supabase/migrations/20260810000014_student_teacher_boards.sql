CREATE OR REPLACE FUNCTION public.get_student_teacher_study_boards()
RETURNS TABLE (
  id UUID, title TEXT, description TEXT, lesson_type TEXT, order_number INT, status TEXT, published_at TIMESTAMPTZ, created_by UUID, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, unit_id UUID
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT l.id, l.title, l.description, l.lesson_type::TEXT, l.order_number, l.status, l.published_at, l.created_by, l.created_at, l.updated_at, l.unit_id
  FROM public.teacher_study_annotations t
  JOIN public.lessons l ON l.id = t.lesson_id
  JOIN public.units u ON u.id = l.unit_id
  JOIN public.groups g ON g.subject_id = u.subject_id
  JOIN public.enrollments e ON e.group_id = g.id
  WHERE e.student_id = public.current_student_id() AND e.status = 'active';
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_student_teacher_study_boards() TO authenticated;
