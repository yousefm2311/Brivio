-- Migration: 20260810000006_grant_options_notify_grades.sql
-- Description: Grant select permissions on question_options to authenticated users and add trigger for grading notifications.

-- 1. Fix missing GRANT for question_options
GRANT SELECT ON public.question_options TO authenticated;

-- 2. Trigger for Graded Homework Notification
CREATE OR REPLACE FUNCTION public.notify_student_on_homework_graded()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_profile_id UUID;
  v_homework_title TEXT;
BEGIN
  -- Only trigger when status changes to 'graded'
  IF NEW.status = 'graded' AND OLD.status != 'graded' THEN
    -- Get the student's profile ID
    SELECT profile_id INTO v_student_profile_id
    FROM public.students
    WHERE id = NEW.student_id;

    -- Get the homework title
    SELECT title INTO v_homework_title
    FROM public.homework
    WHERE id = NEW.homework_id;

    -- Insert notification
    IF v_student_profile_id IS NOT NULL THEN
      INSERT INTO public.app_notifications (
        user_id,
        title,
        message,
        type,
        reference_id
      ) VALUES (
        v_student_profile_id,
        'Homework Graded',
        'Your homework "' || v_homework_title || '" has been graded. You scored ' || NEW.score::TEXT || ' points.',
        'assignment',
        NEW.id
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_notify_homework_graded ON public.homework_submissions;
CREATE TRIGGER tr_notify_homework_graded
AFTER UPDATE ON public.homework_submissions
FOR EACH ROW
EXECUTE FUNCTION public.notify_student_on_homework_graded();
