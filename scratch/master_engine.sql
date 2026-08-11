-- Module 1: Deletions & Moderation
CREATE OR REPLACE FUNCTION delete_branch(branch_id uuid) RETURNS void AS $$
BEGIN
  DELETE FROM branches WHERE id = branch_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_subject(subject_id uuid) RETURNS void AS $$
BEGIN
  DELETE FROM subjects WHERE id = subject_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_group(group_id uuid) RETURNS void AS $$
BEGIN
  DELETE FROM groups WHERE id = group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_curriculum(curriculum_id uuid) RETURNS void AS $$
BEGIN
  DELETE FROM curriculum WHERE id = curriculum_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION suspend_user(user_uid uuid) RETURNS void AS $$
BEGIN
  UPDATE user_profiles SET status = 'suspended' WHERE id = user_uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Module 2: Exam Grading & Override
CREATE OR REPLACE FUNCTION manual_grade_override(
    p_attempt_id uuid,
    p_question_id uuid,
    p_is_correct boolean,
    p_points float
) RETURNS void AS $$
BEGIN
  -- Update the specific question's answer
  UPDATE attempt_answers 
  SET is_correct = p_is_correct, points_awarded = p_points 
  WHERE attempt_id = p_attempt_id AND question_id = p_question_id;

  -- Recalculate total score
  UPDATE exam_attempts 
  SET total_score = (SELECT SUM(points_awarded) FROM attempt_answers WHERE attempt_id = p_attempt_id)
  WHERE id = p_attempt_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
