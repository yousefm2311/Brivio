-- Migration: 20260810000003_assessment_notifications_trigger.sql
-- Description: Add database triggers to automatically create notifications for enrolled students when an exam or homework is published.

CREATE OR REPLACE FUNCTION public.trigger_assessment_notification()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status != 'published')) THEN
        -- Insert notifications for all active students in the group
        INSERT INTO public.notifications (user_id, notification_type, title, body, data)
        SELECT s.profile_id, 
               CASE WHEN TG_TABLE_NAME = 'exams' THEN 'exam_published' ELSE 'homework_published' END,
               CASE WHEN TG_TABLE_NAME = 'exams' THEN 'New Exam: ' || NEW.title ELSE 'New Homework: ' || NEW.title END,
               'A new assessment has been published for your group.',
               jsonb_build_object('group_id', NEW.group_id, 'assessment_id', NEW.id, 'type', TG_TABLE_NAME)
        FROM public.enrollments e
        JOIN public.students s ON s.id = e.student_id
        WHERE e.group_id = NEW.group_id AND e.status = 'active' AND s.profile_id IS NOT NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS notify_students_on_exam_publish ON public.exams;
CREATE TRIGGER notify_students_on_exam_publish
    AFTER INSERT OR UPDATE ON public.exams
    FOR EACH ROW EXECUTE FUNCTION public.trigger_assessment_notification();

DROP TRIGGER IF EXISTS notify_students_on_homework_publish ON public.homework;
CREATE TRIGGER notify_students_on_homework_publish
    AFTER INSERT OR UPDATE ON public.homework
    FOR EACH ROW EXECUTE FUNCTION public.trigger_assessment_notification();
