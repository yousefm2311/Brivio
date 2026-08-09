-- Migration: 20260809000100_admin_runtime_contracts.sql
-- Description: Runtime contracts for admin group operations and assessment authoring.

-- 1. Add the permissions that existing policies/RPCs expect.
INSERT INTO public.permissions (id, code, module, action, description) VALUES
  (gen_random_uuid(), 'students.manage', 'students', 'manage', 'Create, update, and archive student records'),
  (gen_random_uuid(), 'parents.manage', 'parents', 'manage', 'Create, update, and archive parent records'),
  (gen_random_uuid(), 'groups.manage', 'groups', 'manage', 'Create, update, and archive groups'),
  (gen_random_uuid(), 'enrollments.manage', 'enrollments', 'manage', 'Enroll, move, and remove students from groups'),
  (gen_random_uuid(), 'teachers.manage', 'teachers', 'manage', 'Assign and manage teachers'),
  (gen_random_uuid(), 'curriculum.manage', 'curriculum', 'manage', 'Create and update curriculum hierarchy'),
  (gen_random_uuid(), 'questions.manage', 'assessment', 'manage', 'Create and update question bank items'),
  (gen_random_uuid(), 'homework.create', 'assessment', 'create', 'Create homework assignments'),
  (gen_random_uuid(), 'homework.grade', 'assessment', 'grade', 'Grade homework submissions'),
  (gen_random_uuid(), 'exams.create', 'assessment', 'create', 'Create exams'),
  (gen_random_uuid(), 'exams.grade', 'assessment', 'grade', 'Grade exams')
ON CONFLICT (code) DO UPDATE SET
  module = EXCLUDED.module,
  action = EXCLUDED.action,
  description = EXCLUDED.description;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.code IN (
  'students.view',
  'students.manage',
  'parents.view',
  'parents.manage',
  'groups.view',
  'groups.manage',
  'enrollments.view',
  'enrollments.manage',
  'teachers.manage',
  'curriculum.view',
  'curriculum.manage',
  'curriculum.publish',
  'questions.view',
  'questions.manage',
  'homework.create',
  'homework.grade',
  'exams.publish',
  'exams.create',
  'exams.grade',
  'attendance.mark',
  'leave.review',
  'invoices.view',
  'payments.collect'
)
WHERE r.name IN ('super_admin', 'admin', 'staff')
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.code IN (
  'groups.view',
  'enrollments.view',
  'curriculum.view',
  'curriculum.manage',
  'questions.view',
  'questions.manage',
  'homework.create',
  'homework.grade',
  'exams.create',
  'exams.grade',
  'attendance.mark'
)
WHERE r.name = 'teacher'
ON CONFLICT DO NOTHING;

-- 2. Fix helper introduced by the teacher assessment migration. group_teachers has
-- temporal columns, not a status column.
CREATE OR REPLACE FUNCTION public.is_teacher_assigned_to_subject(
  p_teacher_user_id UUID,
  p_subject_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  is_assigned BOOLEAN := false;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM public.teachers t
    JOIN public.group_teachers gt ON gt.teacher_id = t.id
    JOIN public.groups g ON g.id = gt.group_id
    WHERE t.profile_id = p_teacher_user_id
      AND g.subject_id = p_subject_id
      AND gt.effective_from <= CURRENT_DATE
      AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
  ) INTO is_assigned;

  RETURN COALESCE(is_assigned, false);
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_teacher_assigned_to_subject(UUID, UUID) TO authenticated;

-- 3. Teacher assignment RPC used by the admin group details screen.
CREATE OR REPLACE FUNCTION public.assign_teacher_to_group(
  p_teacher_id UUID,
  p_group_id UUID,
  p_role TEXT DEFAULT 'co_teacher'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_role TEXT := lower(trim(COALESCE(p_role, 'co_teacher')));
  teacher_exists BOOLEAN;
  group_exists BOOLEAN;
  primary_flag BOOLEAN;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('groups.manage')
    OR public.has_permission('teachers.manage')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to assign teacher to group' USING ERRCODE = '42501';
  END IF;

  IF normalized_role NOT IN ('primary', 'co_teacher', 'assistant') THEN
    RAISE EXCEPTION 'Invalid teacher group role: %', p_role USING ERRCODE = '22023';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.teachers WHERE id = p_teacher_id AND status = 'active'
  ) INTO teacher_exists;
  IF NOT teacher_exists THEN
    RAISE EXCEPTION 'Active teacher record not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.groups WHERE id = p_group_id AND status = 'active'
  ) INTO group_exists;
  IF NOT group_exists THEN
    RAISE EXCEPTION 'Active group record not found' USING ERRCODE = 'P0002';
  END IF;

  primary_flag := normalized_role = 'primary';

  IF primary_flag THEN
    UPDATE public.group_teachers
    SET is_primary = false,
        role = CASE WHEN role = 'primary' THEN 'co_teacher' ELSE role END
    WHERE group_id = p_group_id
      AND is_primary = true;
  END IF;

  INSERT INTO public.group_teachers (
    group_id,
    teacher_id,
    role,
    is_primary,
    effective_from,
    effective_to
  ) VALUES (
    p_group_id,
    p_teacher_id,
    normalized_role,
    primary_flag,
    CURRENT_DATE,
    NULL
  )
  ON CONFLICT (group_id, teacher_id) DO UPDATE SET
    role = EXCLUDED.role,
    is_primary = EXCLUDED.is_primary,
    effective_from = EXCLUDED.effective_from,
    effective_to = NULL;

  RETURN jsonb_build_object(
    'success', true,
    'teacher_id', p_teacher_id,
    'group_id', p_group_id,
    'role', normalized_role,
    'is_primary', primary_flag
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.assign_teacher_to_group(UUID, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assign_teacher_to_group(UUID, UUID, TEXT) TO authenticated;

DROP POLICY IF EXISTS "Group teachers manageable by authorized permission holders" ON public.group_teachers;
CREATE POLICY "Group teachers manageable by authorized permission holders"
ON public.group_teachers FOR ALL TO authenticated
USING (
  public.is_admin_or_super()
  OR public.has_permission('groups.manage')
  OR public.has_permission('teachers.manage')
)
WITH CHECK (
  public.is_admin_or_super()
  OR public.has_permission('groups.manage')
  OR public.has_permission('teachers.manage')
);

-- 4. Replace enrollment RPC auth with manage permissions.
CREATE OR REPLACE FUNCTION public.enroll_student_in_group(
  p_student_id UUID,
  p_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  g_rec RECORD;
  current_active_count INT;
  s_status TEXT;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('enrollments.manage')
    OR public.has_permission('groups.manage')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to enroll student' USING ERRCODE = '42501';
  END IF;

  SELECT status INTO s_status FROM public.students WHERE id = p_student_id;
  IF s_status IS NULL THEN
    RAISE EXCEPTION 'Student record not found' USING ERRCODE = 'P0002';
  END IF;
  IF s_status <> 'active' THEN
    RAISE EXCEPTION 'Cannot enroll inactive student' USING ERRCODE = '22023';
  END IF;

  SELECT id, max_capacity, capacity, status INTO g_rec
  FROM public.groups
  WHERE id = p_group_id
  FOR UPDATE;

  IF g_rec.id IS NULL THEN
    RAISE EXCEPTION 'Group record not found' USING ERRCODE = 'P0002';
  END IF;
  IF g_rec.status <> 'active' THEN
    RAISE EXCEPTION 'Cannot enroll into inactive group' USING ERRCODE = '22023';
  END IF;

  SELECT COUNT(*)::INT INTO current_active_count
  FROM public.enrollments
  WHERE group_id = p_group_id AND status = 'active';

  IF COALESCE(g_rec.max_capacity, g_rec.capacity) IS NOT NULL
     AND current_active_count >= COALESCE(g_rec.max_capacity, g_rec.capacity) THEN
    RAISE EXCEPTION 'Group capacity exceeded' USING ERRCODE = '54000';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.enrollments
    WHERE student_id = p_student_id
      AND group_id = p_group_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Student is already actively enrolled in this group' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.enrollments (student_id, group_id, status, start_date)
  VALUES (p_student_id, p_group_id, 'active', CURRENT_DATE)
  ON CONFLICT (student_id, group_id) WHERE status = 'active' DO UPDATE SET
    status = 'active',
    start_date = CURRENT_DATE,
    end_date = NULL,
    updated_at = NOW();

  RETURN jsonb_build_object(
    'success', true,
    'student_id', p_student_id,
    'group_id', p_group_id,
    'message', 'Student enrolled successfully'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.enroll_student_in_group(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enroll_student_in_group(UUID, UUID) TO authenticated;

-- 5. Group roster RPC with the full shape expected by Student.fromJson.
DROP FUNCTION IF EXISTS public.get_group_students(UUID);
CREATE OR REPLACE FUNCTION public.get_group_students(p_group_id UUID)
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
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('enrollments.view')
    OR public.has_permission('enrollments.manage')
    OR public.current_teacher_assigned_to_group(p_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view group roster' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.profile_id,
    COALESCE(s.student_code, '')::TEXT AS student_code,
    s.primary_branch_id,
    s.grade_level,
    s.school_name,
    COALESCE(p.full_name, 'Student')::TEXT AS full_name,
    COALESCE(p.email, '')::TEXT AS email,
    COALESCE(s.status, 'active')::TEXT AS status
  FROM public.enrollments e
  JOIN public.students s ON s.id = e.student_id
  LEFT JOIN public.profiles p ON p.id = s.profile_id
  WHERE e.group_id = p_group_id
    AND e.status = 'active'
  ORDER BY COALESCE(p.full_name, s.student_code, s.id::TEXT);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_group_students(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_group_students(UUID) TO authenticated;

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
    AND e.status = 'active'
    AND g.status = 'active'
  ORDER BY 2;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_student_groups(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_student_groups(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_teacher_assigned_groups(p_teacher_id UUID)
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
    OR public.has_permission('groups.view')
    OR p_teacher_id = public.current_teacher_id()
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view teacher groups' USING ERRCODE = '42501';
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
  FROM public.groups g
  WHERE g.status = 'active'
    AND EXISTS (
        SELECT 1
        FROM public.group_teachers gt
        WHERE gt.group_id = g.id
          AND gt.teacher_id = p_teacher_id
          AND gt.effective_from <= CURRENT_DATE
          AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
    )
  ORDER BY 2;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_teacher_assigned_groups(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_assigned_groups(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_teacher_grading_queue(p_teacher_id UUID)
RETURNS TABLE (
  id UUID,
  homework_id UUID,
  student_id UUID,
  status TEXT,
  score NUMERIC,
  submitted_at TIMESTAMPTZ,
  max_score NUMERIC,
  homework_title TEXT,
  group_id UUID,
  student_full_name TEXT,
  student_email TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('homework.grade')
    OR p_teacher_id = public.current_teacher_id()
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view grading queue' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    hs.id,
    hs.homework_id,
    hs.student_id,
    COALESCE(hs.status, 'submitted')::TEXT AS status,
    hs.score,
    hs.submitted_at,
    h.max_score,
    COALESCE(h.title, 'Homework')::TEXT AS homework_title,
    h.group_id,
    COALESCE(p.full_name, 'Student')::TEXT AS student_full_name,
    COALESCE(p.email, '')::TEXT AS student_email
  FROM public.homework_submissions hs
  JOIN public.homework h ON h.id = hs.homework_id
  JOIN public.students s ON s.id = hs.student_id
  LEFT JOIN public.profiles p ON p.id = s.profile_id
  WHERE h.group_id IN (
    SELECT gt.group_id
    FROM public.group_teachers gt
    WHERE gt.teacher_id = p_teacher_id
      AND gt.effective_from <= CURRENT_DATE
      AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
  )
  ORDER BY hs.submitted_at DESC NULLS LAST, hs.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_teacher_grading_queue(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_grading_queue(UUID) TO authenticated;

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_student_lesson_board
ON public.study_annotations(student_id, lesson_id, page_number, annotation_type)
WHERE annotation_type = 'freehand';

CREATE TABLE IF NOT EXISTS public.class_session_boards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_session_id UUID NOT NULL REFERENCES public.class_sessions(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  board_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_published BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_class_session_board UNIQUE (class_session_id)
);

ALTER TABLE public.class_session_boards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Class session boards viewable by participants" ON public.class_session_boards;
CREATE POLICY "Class session boards viewable by participants"
ON public.class_session_boards FOR SELECT TO authenticated
USING (
  public.is_admin_or_super()
  OR public.has_permission('groups.view')
  OR teacher_id = public.current_teacher_id()
  OR (
    is_published
    AND EXISTS (
      SELECT 1
      FROM public.attendance_records ar
      WHERE ar.class_session_id = class_session_boards.class_session_id
        AND ar.student_id = public.current_student_id()
        AND ar.attendance_status IN ('present', 'late')
    )
  )
);

DROP POLICY IF EXISTS "Class session boards manageable by assigned teacher" ON public.class_session_boards;
CREATE POLICY "Class session boards manageable by assigned teacher"
ON public.class_session_boards FOR ALL TO authenticated
USING (
  public.is_admin_or_super()
  OR teacher_id = public.current_teacher_id()
)
WITH CHECK (
  public.is_admin_or_super()
  OR teacher_id = public.current_teacher_id()
);

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
  SELECT
    b.id,
    COALESCE(cs.title, 'Published session board')::TEXT AS title,
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

-- 6. Question authoring contract. The public app reads sanitized options from
-- student_question_options, while this trusted RPC writes the real answer key.
DROP POLICY IF EXISTS "Questions manageable by authorized educators" ON public.questions;
CREATE POLICY "Questions manageable by authorized educators"
ON public.questions FOR ALL TO authenticated
USING (
  public.is_admin_or_super()
  OR public.has_permission('questions.manage')
  OR public.is_teacher_assigned_to_subject(auth.uid(), subject_id)
)
WITH CHECK (
  public.is_admin_or_super()
  OR public.has_permission('questions.manage')
  OR public.is_teacher_assigned_to_subject(auth.uid(), subject_id)
);

DROP POLICY IF EXISTS "Question options manageable by authorized educators" ON public.question_options;
CREATE POLICY "Question options manageable by authorized educators"
ON public.question_options FOR ALL TO authenticated
USING (
  public.is_admin_or_super()
  OR public.has_permission('questions.manage')
  OR EXISTS (
    SELECT 1
    FROM public.questions q
    WHERE q.id = question_options.question_id
      AND public.is_teacher_assigned_to_subject(auth.uid(), q.subject_id)
  )
)
WITH CHECK (
  public.is_admin_or_super()
  OR public.has_permission('questions.manage')
  OR EXISTS (
    SELECT 1
    FROM public.questions q
    WHERE q.id = question_options.question_id
      AND public.is_teacher_assigned_to_subject(auth.uid(), q.subject_id)
  )
);

CREATE OR REPLACE FUNCTION public.create_question_with_options(
  p_subject_id UUID,
  p_unit_id UUID DEFAULT NULL,
  p_lesson_id UUID DEFAULT NULL,
  p_question_type TEXT DEFAULT 'multiple_choice',
  p_prompt TEXT DEFAULT '',
  p_explanation TEXT DEFAULT NULL,
  p_difficulty TEXT DEFAULT 'medium',
  p_default_points NUMERIC DEFAULT 1.00,
  p_options JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_question_id UUID;
  opt JSONB;
  opt_index INT := 0;
  result JSONB;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('questions.manage')
    OR public.is_teacher_assigned_to_subject(auth.uid(), p_subject_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to create question for this subject' USING ERRCODE = '42501';
  END IF;

  IF trim(COALESCE(p_prompt, '')) = '' THEN
    RAISE EXCEPTION 'Question prompt is required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.questions (
    subject_id,
    unit_id,
    lesson_id,
    question_type,
    prompt,
    explanation,
    difficulty,
    default_points,
    status,
    created_by
  ) VALUES (
    p_subject_id,
    p_unit_id,
    p_lesson_id,
    p_question_type,
    p_prompt,
    p_explanation,
    COALESCE(p_difficulty, 'medium'),
    COALESCE(p_default_points, 1.00),
    'active',
    auth.uid()
  )
  RETURNING id INTO new_question_id;

  FOR opt IN SELECT * FROM jsonb_array_elements(COALESCE(p_options, '[]'::jsonb))
  LOOP
    opt_index := opt_index + 1;
    IF trim(COALESCE(opt->>'text', '')) <> '' THEN
      INSERT INTO public.question_options (
        question_id,
        text,
        order_number,
        is_correct
      ) VALUES (
        new_question_id,
        opt->>'text',
        COALESCE((opt->>'order_number')::INT, opt_index),
        COALESCE((opt->>'is_correct')::BOOLEAN, false)
      );
    END IF;
  END LOOP;

  SELECT to_jsonb(q.*) || jsonb_build_object(
    'student_question_options',
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', qo.id,
          'question_id', qo.question_id,
          'text', qo.text,
          'order_number', qo.order_number
        )
        ORDER BY qo.order_number
      )
      FROM public.question_options qo
      WHERE qo.question_id = q.id
    ), '[]'::jsonb)
  )
  INTO result
  FROM public.questions q
  WHERE q.id = new_question_id;

  RETURN result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_question_with_options(
  UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_question_with_options(
  UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB
) TO authenticated;

-- 7. Runtime curriculum authoring contract used by admin/staff curriculum screens.
DROP POLICY IF EXISTS "Semesters manageable by curriculum publishers" ON public.semesters;
CREATE POLICY "Semesters manageable by curriculum publishers"
ON public.semesters FOR ALL TO authenticated
USING (
  public.is_admin_or_super()
  OR public.has_permission('curriculum.manage')
  OR public.has_permission('curriculum.publish')
  OR public.is_teacher_assigned_to_subject(auth.uid(), subject_id)
)
WITH CHECK (
  public.is_admin_or_super()
  OR public.has_permission('curriculum.manage')
  OR public.has_permission('curriculum.publish')
  OR public.is_teacher_assigned_to_subject(auth.uid(), subject_id)
);

DROP POLICY IF EXISTS "Units manageable by curriculum publishers" ON public.units;
CREATE POLICY "Units manageable by curriculum publishers"
ON public.units FOR ALL TO authenticated
USING (
  public.is_admin_or_super()
  OR public.has_permission('curriculum.manage')
  OR public.has_permission('curriculum.publish')
  OR EXISTS (
    SELECT 1
    FROM public.semesters s
    WHERE s.id = units.semester_id
      AND public.is_teacher_assigned_to_subject(auth.uid(), s.subject_id)
  )
)
WITH CHECK (
  public.is_admin_or_super()
  OR public.has_permission('curriculum.manage')
  OR public.has_permission('curriculum.publish')
  OR EXISTS (
    SELECT 1
    FROM public.semesters s
    WHERE s.id = units.semester_id
      AND public.is_teacher_assigned_to_subject(auth.uid(), s.subject_id)
  )
);

DROP POLICY IF EXISTS "Lessons manageable by curriculum publishers" ON public.lessons;
CREATE POLICY "Lessons manageable by curriculum publishers"
ON public.lessons FOR ALL TO authenticated
USING (
  public.is_admin_or_super()
  OR public.has_permission('curriculum.manage')
  OR public.has_permission('curriculum.publish')
  OR EXISTS (
    SELECT 1
    FROM public.units u
    JOIN public.semesters s ON s.id = u.semester_id
    WHERE u.id = lessons.unit_id
      AND public.is_teacher_assigned_to_subject(auth.uid(), s.subject_id)
  )
)
WITH CHECK (
  public.is_admin_or_super()
  OR public.has_permission('curriculum.manage')
  OR public.has_permission('curriculum.publish')
  OR EXISTS (
    SELECT 1
    FROM public.units u
    JOIN public.semesters s ON s.id = u.semester_id
    WHERE u.id = lessons.unit_id
      AND public.is_teacher_assigned_to_subject(auth.uid(), s.subject_id)
  )
);

DROP POLICY IF EXISTS "Lesson resources manageable by curriculum publishers" ON public.lesson_resources;
CREATE POLICY "Lesson resources manageable by curriculum publishers"
ON public.lesson_resources FOR ALL TO authenticated
USING (
  public.is_admin_or_super()
  OR public.has_permission('curriculum.manage')
  OR public.has_permission('curriculum.publish')
  OR EXISTS (
    SELECT 1
    FROM public.lessons l
    JOIN public.units u ON u.id = l.unit_id
    JOIN public.semesters s ON s.id = u.semester_id
    WHERE l.id = lesson_resources.lesson_id
      AND public.is_teacher_assigned_to_subject(auth.uid(), s.subject_id)
  )
)
WITH CHECK (
  public.is_admin_or_super()
  OR public.has_permission('curriculum.manage')
  OR public.has_permission('curriculum.publish')
  OR EXISTS (
    SELECT 1
    FROM public.lessons l
    JOIN public.units u ON u.id = l.unit_id
    JOIN public.semesters s ON s.id = u.semester_id
    WHERE l.id = lesson_resources.lesson_id
      AND public.is_teacher_assigned_to_subject(auth.uid(), s.subject_id)
  )
);

CREATE OR REPLACE FUNCTION public.create_semester_runtime(
  p_subject_id UUID,
  p_name TEXT,
  p_code TEXT,
  p_order_number INT,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL,
  p_status TEXT DEFAULT 'active'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_semester_id UUID;
  v_start_date DATE := COALESCE(p_start_date, CURRENT_DATE);
  v_end_date DATE := COALESCE(p_end_date, (CURRENT_DATE + INTERVAL '120 days')::DATE);
  v_result JSONB;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('curriculum.manage')
    OR public.has_permission('curriculum.publish')
    OR public.is_teacher_assigned_to_subject(auth.uid(), p_subject_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to create semester for this subject' USING ERRCODE = '42501';
  END IF;

  IF trim(COALESCE(p_name, '')) = '' OR trim(COALESCE(p_code, '')) = '' THEN
    RAISE EXCEPTION 'Semester name and code are required' USING ERRCODE = '22023';
  END IF;

  IF v_start_date >= v_end_date THEN
    v_end_date := (v_start_date + INTERVAL '120 days')::DATE;
  END IF;

  INSERT INTO public.semesters (
    subject_id,
    name,
    code,
    order_number,
    start_date,
    end_date,
    status
  ) VALUES (
    p_subject_id,
    trim(p_name),
    trim(p_code),
    COALESCE(p_order_number, 1),
    v_start_date,
    v_end_date,
    COALESCE(p_status, 'active')
  )
  RETURNING id INTO v_semester_id;

  SELECT to_jsonb(s.*) INTO v_result
  FROM public.semesters s
  WHERE s.id = v_semester_id;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_semester_runtime(
  UUID, TEXT, TEXT, INT, DATE, DATE, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_semester_runtime(
  UUID, TEXT, TEXT, INT, DATE, DATE, TEXT
) TO authenticated;

-- 8. Repair teacher assessment RPCs that must match the actual Phase 6 schema.
ALTER TABLE public.homework_submissions
  ADD COLUMN IF NOT EXISTS teacher_feedback TEXT,
  ADD COLUMN IF NOT EXISTS graded_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS graded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.create_homework_assignment(
  p_title TEXT,
  p_description TEXT,
  p_subject_id UUID,
  p_group_id UUID,
  p_due_at TIMESTAMPTZ,
  p_max_score NUMERIC,
  p_status TEXT DEFAULT 'published'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_homework_id UUID;
  v_result JSONB;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('homework.create')
    OR public.current_teacher_assigned_to_group(p_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to create homework for this group' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.homework (
    title,
    description,
    subject_id,
    group_id,
    assigned_by,
    due_at,
    max_score,
    status
  ) VALUES (
    p_title,
    p_description,
    p_subject_id,
    p_group_id,
    auth.uid(),
    p_due_at,
    COALESCE(p_max_score, 100.00),
    COALESCE(p_status, 'published')
  )
  RETURNING id INTO v_homework_id;

  SELECT to_jsonb(h.*) INTO v_result
  FROM public.homework h
  WHERE h.id = v_homework_id;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.grade_homework_submission(
  p_submission_id UUID,
  p_score NUMERIC,
  p_feedback TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id UUID;
  v_max_score NUMERIC;
  v_result JSONB;
BEGIN
  SELECT h.group_id, h.max_score
  INTO v_group_id, v_max_score
  FROM public.homework_submissions s
  JOIN public.homework h ON h.id = s.homework_id
  WHERE s.id = p_submission_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Submission not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('homework.grade')
    OR public.current_teacher_assigned_to_group(v_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to grade homework submission' USING ERRCODE = '42501';
  END IF;

  IF p_score < 0 OR p_score > v_max_score THEN
    RAISE EXCEPTION 'Score out of bounds (0 - %)', v_max_score USING ERRCODE = '22003';
  END IF;

  UPDATE public.homework_submissions
  SET score = p_score,
      teacher_feedback = p_feedback,
      status = 'graded',
      graded_at = NOW(),
      graded_by = auth.uid(),
      updated_at = NOW()
  WHERE id = p_submission_id;

  SELECT to_jsonb(s.*) INTO v_result
  FROM public.homework_submissions s
  WHERE s.id = p_submission_id;

  RETURN v_result;
END;
$$;

DROP FUNCTION IF EXISTS public.create_exam_assignment(TEXT, UUID, UUID, INT, NUMERIC, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.create_exam_assignment(TEXT, UUID, UUID, INT, NUMERIC, TEXT);

CREATE OR REPLACE FUNCTION public.create_exam_assignment(
  p_title TEXT,
  p_subject_id UUID,
  p_group_id UUID,
  p_duration_minutes INT,
  p_pass_score NUMERIC,
  p_status TEXT DEFAULT 'published'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exam_id UUID;
  v_result JSONB;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('exams.create')
    OR public.current_teacher_assigned_to_group(p_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to create exam for this group' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.exams (
    title,
    subject_id,
    group_id,
    duration_minutes,
    pass_score,
    status,
    created_by
  ) VALUES (
    p_title,
    p_subject_id,
    p_group_id,
    COALESCE(p_duration_minutes, 60),
    COALESCE(p_pass_score, 50.00),
    COALESCE(p_status, 'published'),
    auth.uid()
  )
  RETURNING id INTO v_exam_id;

  SELECT to_jsonb(e.*) INTO v_result
  FROM public.exams e
  WHERE e.id = v_exam_id;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_homework_assignment(
  TEXT, TEXT, UUID, UUID, TIMESTAMPTZ, NUMERIC, TEXT
) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.grade_homework_submission(UUID, NUMERIC, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_exam_assignment(
  TEXT, UUID, UUID, INT, NUMERIC, TEXT
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_homework_assignment(
  TEXT, TEXT, UUID, UUID, TIMESTAMPTZ, NUMERIC, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grade_homework_submission(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_exam_assignment(
  TEXT, UUID, UUID, INT, NUMERIC, TEXT
) TO authenticated;

ALTER TABLE public.homework_submissions
  ADD COLUMN IF NOT EXISTS submission_text TEXT,
  ADD COLUMN IF NOT EXISTS attachment_url TEXT;

DROP FUNCTION IF EXISTS public.get_student_homework_feed();
CREATE OR REPLACE FUNCTION public.get_student_homework_feed()
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  subject_id UUID,
  group_id UUID,
  due_at TIMESTAMPTZ,
  max_score NUMERIC,
  status TEXT,
  group_name TEXT,
  submission_status TEXT,
  submission_score NUMERIC,
  teacher_feedback TEXT,
  submitted_at TIMESTAMPTZ
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
  SELECT
    h.id,
    h.title,
    h.description,
    h.subject_id,
    h.group_id,
    h.due_at,
    h.max_score,
    h.status,
    COALESCE(g.name, 'Group')::TEXT AS group_name,
    hs.status AS submission_status,
    hs.score AS submission_score,
    hs.teacher_feedback,
    hs.submitted_at
  FROM public.homework h
  JOIN public.groups g ON g.id = h.group_id
  JOIN public.enrollments e ON e.group_id = h.group_id
  LEFT JOIN public.homework_submissions hs
    ON hs.homework_id = h.id
   AND hs.student_id = v_student_id
  WHERE e.student_id = v_student_id
    AND e.status = 'active'
    AND h.status = 'published'
  ORDER BY h.due_at ASC;
END;
$$;

DROP FUNCTION IF EXISTS public.get_student_exam_feed();
CREATE OR REPLACE FUNCTION public.get_student_exam_feed()
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  subject_id UUID,
  group_id UUID,
  duration_minutes INT,
  max_attempts INT,
  pass_score NUMERIC,
  status TEXT,
  result_release_policy TEXT,
  group_name TEXT,
  attempt_count INT,
  last_attempt_status TEXT,
  last_score NUMERIC
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
  SELECT
    ex.id,
    ex.title,
    ex.description,
    ex.subject_id,
    ex.group_id,
    ex.duration_minutes,
    ex.max_attempts,
    ex.pass_score,
    ex.status,
    ex.result_release_policy,
    COALESCE(g.name, 'Group')::TEXT AS group_name,
    COALESCE(att_stats.attempt_count, 0)::INT AS attempt_count,
    att_stats.last_attempt_status,
    att_stats.last_score
  FROM public.exams ex
  JOIN public.groups g ON g.id = ex.group_id
  JOIN public.enrollments e ON e.group_id = ex.group_id
  LEFT JOIN LATERAL (
    SELECT
      COUNT(*)::INT AS attempt_count,
      (ARRAY_AGG(a.status ORDER BY a.created_at DESC))[1] AS last_attempt_status,
      (ARRAY_AGG(a.score ORDER BY a.created_at DESC))[1] AS last_score
    FROM public.exam_attempts a
    WHERE a.exam_id = ex.id
      AND a.student_id = v_student_id
  ) att_stats ON true
  WHERE e.student_id = v_student_id
    AND e.status = 'active'
    AND ex.status = 'published'
  ORDER BY ex.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.submit_homework_text(UUID, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.submit_homework_text(
  p_homework_id UUID,
  p_submission_text TEXT,
  p_attachment_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
  v_group_id UUID;
  v_submission_id UUID;
  v_result JSONB;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  SELECT group_id INTO v_group_id
  FROM public.homework
  WHERE id = p_homework_id
    AND status = 'published';

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Homework is not available' USING ERRCODE = 'P0002';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.enrollments
    WHERE student_id = v_student_id
      AND group_id = v_group_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Student is not enrolled in this homework group' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.homework_submissions (
    homework_id,
    student_id,
    status,
    submission_text,
    attachment_url,
    submitted_at,
    updated_at
  ) VALUES (
    p_homework_id,
    v_student_id,
    'submitted',
    NULLIF(trim(COALESCE(p_submission_text, '')), ''),
    NULLIF(trim(COALESCE(p_attachment_url, '')), ''),
    NOW(),
    NOW()
  )
  ON CONFLICT (homework_id, student_id) DO UPDATE SET
    status = 'submitted',
    submission_text = EXCLUDED.submission_text,
    attachment_url = EXCLUDED.attachment_url,
    submitted_at = NOW(),
    updated_at = NOW()
  RETURNING id INTO v_submission_id;

  SELECT to_jsonb(s.*) INTO v_result
  FROM public.homework_submissions s
  WHERE s.id = v_submission_id;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_student_homework_feed() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_student_exam_feed() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_homework_text(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_student_homework_feed() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_student_exam_feed() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_homework_text(UUID, TEXT, TEXT) TO authenticated;

DROP FUNCTION IF EXISTS public.get_current_student_attendance_history(INT);
CREATE OR REPLACE FUNCTION public.get_current_student_attendance_history(
  p_limit INT DEFAULT 80
)
RETURNS TABLE (
  id UUID,
  class_session_id UUID,
  student_id UUID,
  attendance_status TEXT,
  marked_at TIMESTAMPTZ,
  notes TEXT,
  session_date DATE,
  scheduled_start_at TIMESTAMPTZ,
  scheduled_end_at TIMESTAMPTZ,
  group_name TEXT,
  group_code TEXT
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
  SELECT
    ar.id,
    ar.class_session_id,
    ar.student_id,
    ar.attendance_status,
    ar.marked_at,
    ar.notes,
    cs.session_date,
    cs.scheduled_start_at,
    cs.scheduled_end_at,
    COALESCE(g.name, 'Group')::TEXT AS group_name,
    COALESCE(g.code, '')::TEXT AS group_code
  FROM public.attendance_records ar
  JOIN public.class_sessions cs ON cs.id = ar.class_session_id
  JOIN public.groups g ON g.id = cs.group_id
  WHERE ar.student_id = v_student_id
  ORDER BY cs.session_date DESC, ar.marked_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 80), 1), 200);
END;
$$;

DROP FUNCTION IF EXISTS public.get_current_student_leave_requests();
CREATE OR REPLACE FUNCTION public.get_current_student_leave_requests()
RETURNS TABLE (
  id UUID,
  student_id UUID,
  class_session_id UUID,
  reason TEXT,
  status TEXT,
  submitted_at TIMESTAMPTZ,
  reviewer_note TEXT,
  session_date DATE,
  group_name TEXT
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
  SELECT
    lr.id,
    lr.student_id,
    lr.class_session_id,
    lr.reason,
    lr.status,
    lr.submitted_at,
    lr.reviewer_note,
    cs.session_date,
    COALESCE(g.name, 'General')::TEXT AS group_name
  FROM public.leave_requests lr
  LEFT JOIN public.class_sessions cs ON cs.id = lr.class_session_id
  LEFT JOIN public.groups g ON g.id = cs.group_id
  WHERE lr.student_id = v_student_id
  ORDER BY lr.submitted_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.create_student_leave_request(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.create_student_leave_request(
  p_class_session_id UUID,
  p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
  v_group_id UUID;
  v_request_id UUID;
  v_result JSONB;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  IF trim(COALESCE(p_reason, '')) = '' THEN
    RAISE EXCEPTION 'Leave reason is required' USING ERRCODE = '22023';
  END IF;

  IF p_class_session_id IS NOT NULL THEN
    SELECT group_id INTO v_group_id
    FROM public.class_sessions
    WHERE id = p_class_session_id;

    IF v_group_id IS NULL THEN
      RAISE EXCEPTION 'Class session not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.enrollments
      WHERE student_id = v_student_id
        AND group_id = v_group_id
        AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'Student is not enrolled in this session group' USING ERRCODE = '42501';
    END IF;
  END IF;

  INSERT INTO public.leave_requests (
    student_id,
    class_session_id,
    reason,
    status,
    submitted_at
  ) VALUES (
    v_student_id,
    p_class_session_id,
    trim(p_reason),
    'pending',
    NOW()
  )
  RETURNING id INTO v_request_id;

  SELECT to_jsonb(lr.*) INTO v_result
  FROM public.leave_requests lr
  WHERE lr.id = v_request_id;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_current_student_attendance_history(INT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_current_student_leave_requests() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_student_leave_request(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_student_attendance_history(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_student_leave_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_student_leave_request(UUID, TEXT) TO authenticated;

-- 9. Refresh PostgREST schema cache so newly-created RPCs are visible immediately.
NOTIFY pgrst, 'reload schema';
