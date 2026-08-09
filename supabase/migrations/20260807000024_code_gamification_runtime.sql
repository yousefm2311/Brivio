-- Migration: 20260807000024_code_gamification_runtime.sql
-- Description: Code playground execution records and gamification runtime tables.

CREATE TABLE IF NOT EXISTS public.code_playground_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE SET NULL,
    language TEXT NOT NULL CHECK (language IN ('python', 'cpp')),
    source_code TEXT NOT NULL,
    stdin TEXT,
    stdout TEXT,
    stderr TEXT,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'timeout')),
    execution_time_ms INT CHECK (execution_time_ms >= 0),
    memory_kb INT CHECK (memory_kb >= 0),
    sandbox_trace_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.gamification_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    icon_url TEXT,
    xp_reward INT NOT NULL DEFAULT 0 CHECK (xp_reward >= 0),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.student_xp_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    reference_table TEXT,
    reference_id UUID,
    xp_amount INT NOT NULL CHECK (xp_amount <> 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.student_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES public.gamification_badges(id) ON DELETE CASCADE,
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    awarded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT unique_student_badge UNIQUE (student_id, badge_id)
);

CREATE OR REPLACE VIEW public.student_gamification_summary AS
SELECT
    s.id AS student_id,
    COALESCE(SUM(xp.xp_amount), 0)::INT AS total_xp,
    COUNT(DISTINCT sb.badge_id)::INT AS badge_count,
    MAX(xp.created_at) AS last_xp_at
FROM public.students s
LEFT JOIN public.student_xp_events xp ON xp.student_id = s.id
LEFT JOIN public.student_badges sb ON sb.student_id = s.id
GROUP BY s.id;

CREATE INDEX IF NOT EXISTS idx_code_submissions_student_lesson ON public.code_playground_submissions(student_id, lesson_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_student_xp_events_student_created ON public.student_xp_events(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_student_badges_student_awarded ON public.student_badges(student_id, awarded_at DESC);

ALTER TABLE public.code_playground_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gamification_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_xp_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Code submissions readable by owner and authorized staff" ON public.code_playground_submissions;
DROP POLICY IF EXISTS "Code submissions writable by owner" ON public.code_playground_submissions;
DROP POLICY IF EXISTS "Gamification badges readable by authenticated users" ON public.gamification_badges;
DROP POLICY IF EXISTS "Gamification badges managed by admins" ON public.gamification_badges;
DROP POLICY IF EXISTS "XP events readable by owner and guardians" ON public.student_xp_events;
DROP POLICY IF EXISTS "XP events inserted by trusted roles" ON public.student_xp_events;
DROP POLICY IF EXISTS "Student badges readable by owner and guardians" ON public.student_badges;
DROP POLICY IF EXISTS "Student badges awarded by trusted roles" ON public.student_badges;

CREATE POLICY "Code submissions readable by owner and authorized staff" ON public.code_playground_submissions
FOR SELECT TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    OR (
        public.current_user_role() = 'teacher'
        AND EXISTS (
            SELECT 1 FROM public.enrollments e
            JOIN public.group_teachers gt ON gt.group_id = e.group_id
            WHERE e.student_id = code_playground_submissions.student_id
              AND gt.teacher_id = public.get_teacher_id(auth.uid())
              AND e.status = 'active'
        )
    )
);

CREATE POLICY "Code submissions writable by owner" ON public.code_playground_submissions
FOR INSERT TO authenticated WITH CHECK (
    student_id = public.get_student_id(auth.uid())
    AND (
        lesson_id IS NULL
        OR public.current_student_can_access_lesson(lesson_id)
    )
);

CREATE POLICY "Gamification badges readable by authenticated users" ON public.gamification_badges
FOR SELECT TO authenticated USING (status = 'active' OR public.current_user_role() IN ('admin', 'staff', 'super_admin'));

CREATE POLICY "Gamification badges managed by admins" ON public.gamification_badges
FOR ALL TO authenticated USING (
    public.current_user_role() IN ('admin', 'super_admin')
) WITH CHECK (
    public.current_user_role() IN ('admin', 'super_admin')
);

CREATE POLICY "XP events readable by owner and guardians" ON public.student_xp_events
FOR SELECT TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
    OR public.is_parent_of_student(auth.uid(), student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
);

CREATE POLICY "XP events inserted by trusted roles" ON public.student_xp_events
FOR INSERT TO authenticated WITH CHECK (
    student_id = public.get_student_id(auth.uid())
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
);

CREATE POLICY "Student badges readable by owner and guardians" ON public.student_badges
FOR SELECT TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
    OR public.is_parent_of_student(auth.uid(), student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
);

CREATE POLICY "Student badges awarded by trusted roles" ON public.student_badges
FOR INSERT TO authenticated WITH CHECK (
    public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
);
