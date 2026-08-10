-- Migration: 20260810000012_app_notifications_triggers.sql
-- Description: Triggers for lessons, homework, exams, and grading to insert into app_notifications

-- 1. Lesson Published
CREATE OR REPLACE FUNCTION public.trigger_notify_on_lesson_published()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status != 'published')) THEN
        INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
        SELECT DISTINCT s.profile_id,
               'New Lesson Published',
               'A new lesson "' || NEW.title || '" has been added to your course.',
               'lesson',
               NEW.id
        FROM public.units u
        JOIN public.groups g ON g.subject_id = u.subject_id
        JOIN public.enrollments e ON e.group_id = g.id
        JOIN public.students s ON s.id = e.student_id
        WHERE u.id = NEW.unit_id 
          AND e.status = 'active' 
          AND g.status = 'active' 
          AND s.profile_id IS NOT NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS notify_students_on_lesson_publish ON public.lessons;
CREATE TRIGGER notify_students_on_lesson_publish
    AFTER INSERT OR UPDATE ON public.lessons
    FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_on_lesson_published();

-- 2. Assessment Published (Exams and Homework)
CREATE OR REPLACE FUNCTION public.trigger_notify_on_assessment_published()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status != 'published')) THEN
        IF NEW.group_id IS NOT NULL THEN
            INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
            SELECT DISTINCT s.profile_id,
                   CASE WHEN TG_TABLE_NAME = 'exams' THEN 'New Exam Published' ELSE 'New Homework Published' END,
                   CASE WHEN TG_TABLE_NAME = 'exams' THEN 'A new exam "' || NEW.title || '" has been scheduled.' ELSE 'New homework "' || NEW.title || '" has been assigned.' END,
                   CASE WHEN TG_TABLE_NAME = 'exams' THEN 'exam' ELSE 'homework' END,
                   NEW.id
            FROM public.enrollments e
            JOIN public.students s ON s.id = e.student_id
            WHERE e.group_id = NEW.group_id 
              AND e.status = 'active' 
              AND s.profile_id IS NOT NULL;
        ELSE
            -- Fallback: notify all groups in the subject
            INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
            SELECT DISTINCT s.profile_id,
                   CASE WHEN TG_TABLE_NAME = 'exams' THEN 'New Exam Published' ELSE 'New Homework Published' END,
                   CASE WHEN TG_TABLE_NAME = 'exams' THEN 'A new exam "' || NEW.title || '" has been scheduled.' ELSE 'New homework "' || NEW.title || '" has been assigned.' END,
                   CASE WHEN TG_TABLE_NAME = 'exams' THEN 'exam' ELSE 'homework' END,
                   NEW.id
            FROM public.groups g
            JOIN public.enrollments e ON e.group_id = g.id
            JOIN public.students s ON s.id = e.student_id
            WHERE g.subject_id = NEW.subject_id 
              AND e.status = 'active' 
              AND g.status = 'active'
              AND s.profile_id IS NOT NULL;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS notify_students_on_exam_publish ON public.exams;
CREATE TRIGGER notify_students_on_exam_publish
    AFTER INSERT OR UPDATE ON public.exams
    FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_on_assessment_published();

DROP TRIGGER IF EXISTS notify_students_on_homework_publish ON public.homework;
CREATE TRIGGER notify_students_on_homework_publish
    AFTER INSERT OR UPDATE ON public.homework
    FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_on_assessment_published();

-- 3. Grading Notifications (Submissions and Attempts)
CREATE OR REPLACE FUNCTION public.trigger_notify_on_submission_graded()
RETURNS TRIGGER AS $$
DECLARE
    v_profile_id UUID;
    v_title TEXT;
BEGIN
    IF NEW.status = 'graded' AND (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status != 'graded')) THEN
        
        -- Get the student's profile ID
        SELECT profile_id INTO v_profile_id FROM public.students WHERE id = NEW.student_id;
        
        IF v_profile_id IS NOT NULL THEN
            IF TG_TABLE_NAME = 'exam_attempts' THEN
                SELECT title INTO v_title FROM public.exams WHERE id = NEW.exam_id;
                IF v_title IS NOT NULL THEN
                    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
                    VALUES (v_profile_id, 'Exam Graded', 'Your attempt for "' || v_title || '" has been graded. Score: ' || COALESCE(NEW.score::text, 'N/A'), 'grade', NEW.id);
                END IF;
            ELSIF TG_TABLE_NAME = 'homework_submissions' THEN
                SELECT title INTO v_title FROM public.homework WHERE id = NEW.homework_id;
                IF v_title IS NOT NULL THEN
                    INSERT INTO public.app_notifications (user_id, title, message, type, reference_id)
                    VALUES (v_profile_id, 'Homework Graded', 'Your submission for "' || v_title || '" has been graded. Score: ' || COALESCE(NEW.score::text, 'N/A'), 'grade', NEW.id);
                END IF;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS notify_student_on_exam_graded ON public.exam_attempts;
CREATE TRIGGER notify_student_on_exam_graded
    AFTER INSERT OR UPDATE ON public.exam_attempts
    FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_on_submission_graded();

DROP TRIGGER IF EXISTS notify_student_on_homework_graded ON public.homework_submissions;
CREATE TRIGGER notify_student_on_homework_graded
    AFTER INSERT OR UPDATE ON public.homework_submissions
    FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_on_submission_graded();
