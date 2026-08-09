-- Migration: 20260809000400_student_gamification_runtime.sql
-- Description: Real student XP/level/streak summary and idempotent lesson-completion XP.

CREATE UNIQUE INDEX IF NOT EXISTS idx_student_xp_events_unique_lesson_completion
ON public.student_xp_events(student_id, event_type, reference_table, reference_id)
WHERE event_type = 'lesson_completed'
  AND reference_table = 'lessons'
  AND reference_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.update_lesson_progress(
    p_lesson_id UUID,
    p_status TEXT,
    p_progress_percentage INT DEFAULT 0,
    p_last_position_seconds INT DEFAULT 0,
    p_time_spent_seconds INT DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
    s_id UUID;
    bounded_progress INT;
    is_completed BOOLEAN;
    was_completed BOOLEAN := false;
    awarded_xp INT := 0;
BEGIN
    SELECT id INTO s_id FROM public.students WHERE profile_id = auth.uid();
    IF s_id IS NULL THEN
        RAISE EXCEPTION 'Only active enrolled students can update lesson progress' USING ERRCODE = '42501';
    END IF;

    IF NOT public.current_student_can_access_lesson(p_lesson_id) THEN
        RAISE EXCEPTION 'Unauthorized to access this lesson' USING ERRCODE = '42501';
    END IF;

    SELECT status = 'completed'
    INTO was_completed
    FROM public.lesson_progress
    WHERE student_id = s_id
      AND lesson_id = p_lesson_id;

    bounded_progress := GREATEST(0, LEAST(100, p_progress_percentage));
    is_completed := (p_status = 'completed' OR bounded_progress >= 100);

    INSERT INTO public.lesson_progress (
        student_id,
        lesson_id,
        status,
        progress_percentage,
        last_position,
        time_spent_seconds,
        completed_at,
        last_accessed_at
    )
    VALUES (
        s_id,
        p_lesson_id,
        CASE WHEN is_completed THEN 'completed' ELSE p_status END,
        bounded_progress,
        p_last_position_seconds::text,
        p_time_spent_seconds,
        CASE WHEN is_completed THEN NOW() ELSE NULL END,
        NOW()
    )
    ON CONFLICT (student_id, lesson_id) DO UPDATE SET
        status = CASE WHEN EXCLUDED.status = 'completed' OR lesson_progress.status = 'completed' THEN 'completed' ELSE EXCLUDED.status END,
        progress_percentage = GREATEST(lesson_progress.progress_percentage, EXCLUDED.progress_percentage),
        last_position = EXCLUDED.last_position,
        time_spent_seconds = lesson_progress.time_spent_seconds + EXCLUDED.time_spent_seconds,
        completed_at = COALESCE(lesson_progress.completed_at, CASE WHEN EXCLUDED.status = 'completed' THEN NOW() ELSE NULL END),
        last_accessed_at = NOW();

    IF is_completed AND NOT COALESCE(was_completed, false) THEN
        INSERT INTO public.student_xp_events (
            student_id,
            event_type,
            reference_table,
            reference_id,
            xp_amount
        )
        VALUES (
            s_id,
            'lesson_completed',
            'lessons',
            p_lesson_id,
            100
        )
        ON CONFLICT DO NOTHING;

        GET DIAGNOSTICS awarded_xp = ROW_COUNT;
        awarded_xp := awarded_xp * 100;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'student_id', s_id,
        'lesson_id', p_lesson_id,
        'progress_percentage', bounded_progress,
        'completed', is_completed,
        'awarded_xp', awarded_xp
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS public.get_current_student_gamification_summary();
CREATE OR REPLACE FUNCTION public.get_current_student_gamification_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    s_id UUID := public.current_student_id();
    total_xp INT := 0;
    badge_count INT := 0;
    last_xp TIMESTAMPTZ;
    level_no INT := 1;
    level_floor INT := 0;
    level_progress INT := 0;
    xp_to_next INT := 500;
    streak_days INT := 0;
    expected_day DATE;
    day_row DATE;
    badges_json JSONB := '[]'::jsonb;
BEGIN
    IF s_id IS NULL THEN
        RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
    END IF;

    SELECT
        COALESCE(SUM(xp_amount), 0)::INT,
        MAX(created_at)
    INTO total_xp, last_xp
    FROM public.student_xp_events
    WHERE student_id = s_id;

    SELECT COUNT(*)::INT
    INTO badge_count
    FROM public.student_badges
    WHERE student_id = s_id;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'name', b.name,
                'code', b.code,
                'awarded_at', sb.awarded_at,
                'xp_reward', b.xp_reward
            )
            ORDER BY sb.awarded_at DESC
        ),
        '[]'::jsonb
    )
    INTO badges_json
    FROM public.student_badges sb
    JOIN public.gamification_badges b ON b.id = sb.badge_id
    WHERE sb.student_id = s_id;

    level_no := GREATEST(1, FLOOR(total_xp / 500)::INT + 1);
    level_floor := (level_no - 1) * 500;
    xp_to_next := GREATEST(0, (level_no * 500) - total_xp);
    level_progress := GREATEST(0, LEAST(100, FLOOR(((total_xp - level_floor)::NUMERIC / 500) * 100)::INT));

    IF last_xp IS NOT NULL THEN
        expected_day := CASE
            WHEN last_xp::DATE >= CURRENT_DATE THEN CURRENT_DATE
            WHEN last_xp::DATE = CURRENT_DATE - 1 THEN CURRENT_DATE - 1
            ELSE NULL
        END;

        IF expected_day IS NOT NULL THEN
            FOR day_row IN
                SELECT DISTINCT created_at::DATE AS xp_day
                FROM public.student_xp_events
                WHERE student_id = s_id
                ORDER BY xp_day DESC
            LOOP
                IF day_row = expected_day THEN
                    streak_days := streak_days + 1;
                    expected_day := expected_day - 1;
                ELSIF day_row < expected_day THEN
                    EXIT;
                END IF;
            END LOOP;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'total_xp', total_xp,
        'level', level_no,
        'level_progress_percentage', level_progress,
        'xp_to_next_level', xp_to_next,
        'streak_days', streak_days,
        'badge_count', badge_count,
        'last_xp_at', last_xp,
        'badges', badges_json
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_lesson_progress(UUID, TEXT, INT, INT, INT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_current_student_gamification_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_lesson_progress(UUID, TEXT, INT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_student_gamification_summary() TO authenticated;

NOTIFY pgrst, 'reload schema';
