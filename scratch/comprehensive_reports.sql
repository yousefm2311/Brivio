-- Comprehensive Reporting RPCs for Supabase
-- Instructions for User:
-- 1. Go to your Supabase project dashboard -> SQL Editor.
-- 2. Paste the contents of this file into a new query.
-- 3. Click "Run" to create these RPCs for the reports system.

CREATE OR REPLACE FUNCTION get_student_performance_report(p_class_id UUID)
RETURNS TABLE (
    student_id UUID,
    student_name TEXT,
    exam_score NUMERIC,
    homework_score NUMERIC,
    missing_assignments INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id AS student_id,
        s.full_name AS student_name,
        COALESCE(AVG(e.score), 0) AS exam_score,
        COALESCE(AVG(h.score), 0) AS homework_score,
        COALESCE(COUNT(h.id) FILTER (WHERE h.status = 'missing'), 0)::INTEGER AS missing_assignments
    FROM students s
    LEFT JOIN exam_scores e ON s.id = e.student_id
    LEFT JOIN homework_submissions h ON s.id = h.student_id
    WHERE s.class_id = p_class_id
    GROUP BY s.id, s.full_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_teacher_metrics_report()
RETURNS TABLE (
    teacher_id UUID,
    teacher_name TEXT,
    classes_taught INTEGER,
    average_attendance_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id AS teacher_id,
        t.full_name AS teacher_name,
        COUNT(DISTINCT c.id)::INTEGER AS classes_taught,
        COALESCE(AVG(ar.is_present::INT), 0) * 100 AS average_attendance_rate
    FROM teachers t
    LEFT JOIN classes c ON t.id = c.teacher_id
    LEFT JOIN class_sessions cs ON c.id = cs.class_id
    LEFT JOIN attendance_records ar ON cs.id = ar.session_id
    GROUP BY t.id, t.full_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_exam_analysis_report(p_exam_id UUID)
RETURNS TABLE (
    exam_id UUID,
    exam_name TEXT,
    average_score NUMERIC,
    highest_score NUMERIC,
    lowest_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id AS exam_id,
        e.title AS exam_name,
        AVG(es.score) AS average_score,
        MAX(es.score) AS highest_score,
        MIN(es.score) AS lowest_score
    FROM exams e
    LEFT JOIN exam_scores es ON e.id = es.exam_id
    WHERE e.id = p_exam_id
    GROUP BY e.id, e.title;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
