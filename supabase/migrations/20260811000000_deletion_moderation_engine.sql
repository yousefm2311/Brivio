-- Migration: 20260811000000_deletion_moderation_engine.sql
-- Description: Module 1: Deletions & Moderation RPCs with RLS respect

CREATE OR REPLACE FUNCTION soft_delete_user(target_user_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF public.is_admin_or_super() THEN
        UPDATE public.profiles SET status = 'suspended' WHERE id = target_user_id;
    ELSE
        RAISE EXCEPTION 'Only admins can suspend users.';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION suspend_user(user_uid uuid) RETURNS void AS $$
BEGIN
  PERFORM soft_delete_user(user_uid);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_branch(branch_id uuid) RETURNS void AS $$
BEGIN
  IF public.is_admin_or_super() THEN
    DELETE FROM public.branches WHERE id = branch_id;
  ELSE
    RAISE EXCEPTION 'Not authorized to delete branches.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_subject(subject_id uuid) RETURNS void AS $$
BEGIN
  IF public.is_admin_or_super() THEN
    DELETE FROM public.subjects WHERE id = subject_id;
  ELSE
    RAISE EXCEPTION 'Not authorized to delete subjects.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_group(group_id uuid) RETURNS void AS $$
BEGIN
  IF public.is_admin_or_super() OR public.current_teacher_assigned_to_group(group_id) THEN
    DELETE FROM public.groups WHERE id = group_id;
  ELSE
    RAISE EXCEPTION 'Not authorized to delete this group.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_exam(exam_id uuid) RETURNS void AS $$
DECLARE
  grp_id uuid;
BEGIN
  SELECT group_id INTO grp_id FROM public.exams WHERE id = exam_id;
  IF public.is_admin_or_super() OR public.current_teacher_assigned_to_group(grp_id) THEN
    DELETE FROM public.exams WHERE id = exam_id;
  ELSE
    RAISE EXCEPTION 'Not authorized to delete this exam.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_homework(homework_id uuid) RETURNS void AS $$
DECLARE
  grp_id uuid;
BEGIN
  SELECT group_id INTO grp_id FROM public.homework WHERE id = homework_id;
  IF public.is_admin_or_super() OR public.current_teacher_assigned_to_group(grp_id) THEN
    DELETE FROM public.homework WHERE id = homework_id;
  ELSE
    RAISE EXCEPTION 'Not authorized to delete this homework.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_lesson(lesson_id uuid) RETURNS void AS $$
BEGIN
  IF public.is_admin_or_super() THEN
    DELETE FROM public.lessons WHERE id = lesson_id;
  ELSE
    RAISE EXCEPTION 'Not authorized to delete lessons.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_unit(unit_id uuid) RETURNS void AS $$
BEGIN
  IF public.is_admin_or_super() THEN
    DELETE FROM public.units WHERE id = unit_id;
  ELSE
    RAISE EXCEPTION 'Not authorized to delete units.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_semester(semester_id uuid) RETURNS void AS $$
BEGIN
  IF public.is_admin_or_super() THEN
    DELETE FROM public.semesters WHERE id = semester_id;
  ELSE
    RAISE EXCEPTION 'Not authorized to delete semesters.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
