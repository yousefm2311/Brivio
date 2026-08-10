-- Migration: 20260810000007_teacher_exam_reset.sql
-- Description: Create RPC to allow teachers to reset a student's exam attempt.

-- 1. Create function to reset exam attempt
CREATE OR REPLACE FUNCTION public.reset_student_exam_attempt(p_exam_id UUID, p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID;
  v_group_id UUID;
BEGIN
  -- Verify the teacher
  v_teacher_id := public.current_teacher_id();
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Only teachers can reset exams' USING ERRCODE = '42501';
  END IF;

  -- Get the group for this exam
  SELECT group_id INTO v_group_id
  FROM public.exams
  WHERE id = p_exam_id;

  -- Verify the teacher is assigned to this group
  IF NOT public.current_teacher_assigned_to_group(v_group_id) THEN
    RAISE EXCEPTION 'Teacher is not assigned to this group' USING ERRCODE = '42501';
  END IF;

  -- Delete all attempts for this student on this exam
  -- Note: Cascading delete will remove associated exam_answers and exam_submissions
  DELETE FROM public.exam_attempts
  WHERE exam_id = p_exam_id AND student_id = p_student_id;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reset_student_exam_attempt(UUID, UUID) TO authenticated;
