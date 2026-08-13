-- Final database contract cleanup for runtime/schema drift found after the
-- earlier hotfix migrations were applied.

-- 1. Backwards compatibility for older app code that used parent_student_links.
-- The canonical table is public.parent_students.
DO $$
DECLARE
  has_relationship_type BOOLEAN;
  has_is_primary BOOLEAN;
  has_created_at BOOLEAN;
  has_status BOOLEAN;
  copy_sql TEXT;
BEGIN
  IF to_regclass('public.parent_student_links') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public'
         AND c.relname = 'parent_student_links'
         AND c.relkind = 'v'
     ) THEN
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'parent_student_links'
        AND column_name = 'relationship_type'
    ) INTO has_relationship_type;

    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'parent_student_links'
        AND column_name = 'is_primary'
    ) INTO has_is_primary;

    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'parent_student_links'
        AND column_name = 'created_at'
    ) INTO has_created_at;

    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'parent_student_links'
        AND column_name = 'status'
    ) INTO has_status;

    copy_sql := format(
      'INSERT INTO public.parent_students (parent_id, student_id, relationship_type, is_primary, created_at)
       SELECT parent_id,
              student_id,
              %s,
              %s,
              %s
       FROM public.parent_student_links
       %s
       ON CONFLICT (parent_id, student_id) DO UPDATE
       SET relationship_type = EXCLUDED.relationship_type,
           is_primary = EXCLUDED.is_primary',
      CASE
        WHEN has_relationship_type
          THEN 'COALESCE(NULLIF(relationship_type, ''''), ''guardian'')'
        ELSE '''guardian'''
      END,
      CASE WHEN has_is_primary THEN 'COALESCE(is_primary, false)' ELSE 'false' END,
      CASE WHEN has_created_at THEN 'COALESCE(created_at, NOW())' ELSE 'NOW()' END,
      CASE
        WHEN has_status THEN 'WHERE COALESCE(status, ''active'') = ''active'''
        ELSE ''
      END
    );

    EXECUTE copy_sql;

    DROP TABLE public.parent_student_links CASCADE;
  END IF;
END $$;

CREATE OR REPLACE VIEW public.parent_student_links AS
SELECT
  parent_id,
  student_id,
  relationship_type,
  is_primary,
  created_at,
  'active'::TEXT AS status
FROM public.parent_students;

CREATE OR REPLACE FUNCTION public.parent_student_links_write_through()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.parent_students (
      parent_id,
      student_id,
      relationship_type,
      is_primary
    )
    VALUES (
      NEW.parent_id,
      NEW.student_id,
      COALESCE(NULLIF(NEW.relationship_type, ''), 'guardian'),
      COALESCE(NEW.is_primary, false)
    )
    ON CONFLICT (parent_id, student_id) DO UPDATE
    SET relationship_type = EXCLUDED.relationship_type,
        is_primary = EXCLUDED.is_primary;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.parent_students
    SET relationship_type = COALESCE(
          NULLIF(NEW.relationship_type, ''),
          public.parent_students.relationship_type
        ),
        is_primary = COALESCE(NEW.is_primary, public.parent_students.is_primary)
    WHERE parent_id = OLD.parent_id
      AND student_id = OLD.student_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM public.parent_students
    WHERE parent_id = OLD.parent_id
      AND student_id = OLD.student_id;
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS tr_parent_student_links_write_through
ON public.parent_student_links;

CREATE TRIGGER tr_parent_student_links_write_through
INSTEAD OF INSERT OR UPDATE OR DELETE ON public.parent_student_links
FOR EACH ROW
EXECUTE FUNCTION public.parent_student_links_write_through();

GRANT SELECT, INSERT, UPDATE, DELETE ON public.parent_student_links TO authenticated;

-- 2. Keep question answer keys away from students. Students read the sanitized
-- student_question_options view; educators/admins can still read the real table
-- for grading and question management.
GRANT SELECT ON public.student_question_options TO authenticated;
GRANT SELECT ON public.question_options TO authenticated;

DROP POLICY IF EXISTS "Question options viewable by authorized users"
ON public.question_options;

DROP POLICY IF EXISTS "Question options viewable by educators and admins"
ON public.question_options;

CREATE POLICY "Question options viewable by educators and admins"
ON public.question_options FOR SELECT TO authenticated
USING (
  public.is_admin_or_super()
  OR public.has_permission('questions.view')
  OR public.has_permission('questions.manage')
  OR EXISTS (
    SELECT 1
    FROM public.questions q
    WHERE q.id = question_options.question_id
      AND public.is_teacher_assigned_to_subject(auth.uid(), q.subject_id)
  )
);

-- 3. Make subjects.name/title drift safe without assuming optional columns
-- exist on already-mutated remote databases.
DO $$
DECLARE
  has_name BOOLEAN;
  has_title BOOLEAN;
  has_code BOOLEAN;
BEGIN
  IF to_regclass('public.subjects') IS NULL THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'subjects'
      AND column_name = 'name'
  ) INTO has_name;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'subjects'
      AND column_name = 'title'
  ) INTO has_title;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'subjects'
      AND column_name = 'code'
  ) INTO has_code;

  IF NOT has_name THEN
    ALTER TABLE public.subjects ADD COLUMN name TEXT;
  END IF;

  IF has_title AND has_code THEN
    EXECUTE 'UPDATE public.subjects SET name = COALESCE(NULLIF(name, ''''), NULLIF(title, ''''), NULLIF(code, ''''), ''Subject'')';
  ELSIF has_title THEN
    EXECUTE 'UPDATE public.subjects SET name = COALESCE(NULLIF(name, ''''), NULLIF(title, ''''), ''Subject'')';
  ELSIF has_code THEN
    EXECUTE 'UPDATE public.subjects SET name = COALESCE(NULLIF(name, ''''), NULLIF(code, ''''), ''Subject'')';
  ELSE
    UPDATE public.subjects
    SET name = COALESCE(NULLIF(name, ''), 'Subject');
  END IF;

  ALTER TABLE public.subjects ALTER COLUMN name SET NOT NULL;
END $$;

NOTIFY pgrst, 'reload schema';
