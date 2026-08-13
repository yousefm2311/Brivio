-- Runtime fixes for parent/student identity lookups and account QR login.

CREATE OR REPLACE FUNCTION public.current_student_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT id INTO s_id
  FROM public.students
  WHERE profile_id = auth.uid()
    AND COALESCE(status, 'active') = 'active'
  LIMIT 1;

  RETURN s_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.current_parent_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  p_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT id INTO p_id
  FROM public.parents
  WHERE profile_id = auth.uid()
    AND COALESCE(status, 'active') = 'active'
  LIMIT 1;

  RETURN p_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_current_parent_children()
RETURNS TABLE (
  id UUID,
  profile_id UUID,
  student_code TEXT,
  primary_branch_id UUID,
  grade_level TEXT,
  school_name TEXT,
  full_name TEXT,
  email TEXT,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_parent_id UUID := public.current_parent_id();
BEGIN
  IF v_parent_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.profile_id,
    COALESCE(s.student_code, '')::TEXT,
    s.primary_branch_id,
    s.grade_level,
    s.school_name,
    COALESCE(p.full_name, s.student_code, 'Student')::TEXT,
    COALESCE(p.email, '')::TEXT,
    COALESCE(s.status, 'active')::TEXT
  FROM public.parent_students ps
  JOIN public.students s ON s.id = ps.student_id
  LEFT JOIN public.profiles p ON p.id = s.profile_id
  WHERE ps.parent_id = v_parent_id
  ORDER BY COALESCE(ps.is_primary, false) DESC, COALESCE(p.full_name, s.student_code, s.id::TEXT);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.current_student_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_parent_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_current_parent_children() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.current_student_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_parent_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_parent_children() TO authenticated;

NOTIFY pgrst, 'reload schema';
