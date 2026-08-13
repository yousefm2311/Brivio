-- Compatibility fix for projects that were created with subjects.title instead
-- of subjects.name. Runtime SQL functions expect subjects.name.
DO $$
BEGIN
  IF to_regclass('public.subjects') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'subjects'
         AND column_name = 'name'
     ) THEN
    ALTER TABLE public.subjects ADD COLUMN name TEXT;

    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'subjects'
        AND column_name = 'title'
    ) THEN
      EXECUTE 'UPDATE public.subjects SET name = COALESCE(NULLIF(title, ''''), code, ''Subject'') WHERE name IS NULL';
    ELSE
      UPDATE public.subjects
      SET name = COALESCE(code, 'Subject')
      WHERE name IS NULL;
    END IF;

    ALTER TABLE public.subjects ALTER COLUMN name SET NOT NULL;
  END IF;
END $$;
