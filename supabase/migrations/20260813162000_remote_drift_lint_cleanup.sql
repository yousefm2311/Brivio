-- Cleanup for legacy functions/constraints found on drifted remote databases.

DROP FUNCTION IF EXISTS public.delete_curriculum(UUID);
DROP FUNCTION IF EXISTS public.generate_account_login_token(UUID);
DROP FUNCTION IF EXISTS public.get_student_performance_report(UUID);
DROP FUNCTION IF EXISTS public.get_teacher_metrics_report();
DROP FUNCTION IF EXISTS public.get_exam_analysis_report(UUID);

-- The homework submission RPCs use ON CONFLICT. Some manually-mutated remote
-- databases are missing the original unique constraints, so normalize duplicate
-- rows before restoring the constraints.
DO $$
BEGIN
  IF to_regclass('public.homework_answers') IS NOT NULL THEN
    DELETE FROM public.homework_answers ha
    USING public.homework_answers newer
    WHERE ha.submission_id = newer.submission_id
      AND ha.question_id = newer.question_id
      AND (
        ha.created_at < newer.created_at
        OR (ha.created_at = newer.created_at AND ha.id < newer.id)
      );
  END IF;

  IF to_regclass('public.homework_submissions') IS NOT NULL THEN
    DELETE FROM public.homework_submissions hs
    USING public.homework_submissions newer
    WHERE hs.homework_id = newer.homework_id
      AND hs.student_id = newer.student_id
      AND (
        hs.created_at < newer.created_at
        OR (hs.created_at = newer.created_at AND hs.id < newer.id)
      );
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.homework_submissions') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM pg_constraint
       WHERE conname = 'unique_student_homework_submission'
         AND conrelid = 'public.homework_submissions'::regclass
     ) THEN
    ALTER TABLE public.homework_submissions
      ADD CONSTRAINT unique_student_homework_submission
      UNIQUE (homework_id, student_id);
  END IF;

  IF to_regclass('public.homework_answers') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM pg_constraint
       WHERE conname = 'unique_submission_question_answer'
         AND conrelid = 'public.homework_answers'::regclass
     ) THEN
    ALTER TABLE public.homework_answers
      ADD CONSTRAINT unique_submission_question_answer
      UNIQUE (submission_id, question_id);
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
