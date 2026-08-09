-- Migration: 20260807000023_smart_study_workspace.sql
-- Description: Smart Study Workspace persistence, sync, and replay foundation.

ALTER TABLE public.lesson_resources
ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.study_notebooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    content TEXT NOT NULL DEFAULT '',
    sync_version INT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_study_notebook UNIQUE (student_id, lesson_id)
);

CREATE TABLE IF NOT EXISTS public.study_code_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    language TEXT NOT NULL DEFAULT 'python',
    code TEXT NOT NULL DEFAULT '',
    last_run_output TEXT,
    last_run_status TEXT,
    sync_version INT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_study_code_draft UNIQUE (student_id, lesson_id, language)
);

CREATE TABLE IF NOT EXISTS public.study_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    page_number INT NOT NULL CHECK (page_number > 0),
    title TEXT,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'study_annotation_type') THEN
        CREATE TYPE study_annotation_type AS ENUM (
            'highlight',
            'freehand',
            'shape',
            'text',
            'sticky_note'
        );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.study_annotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    page_number INT NOT NULL CHECK (page_number > 0),
    annotation_type study_annotation_type NOT NULL,
    color TEXT,
    geometry JSONB NOT NULL DEFAULT '{}'::jsonb,
    content TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.study_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_seconds INT NOT NULL DEFAULT 0 CHECK (duration_seconds >= 0),
    pages_read INT NOT NULL DEFAULT 0 CHECK (pages_read >= 0),
    device_id TEXT,
    consent_teacher_replay BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS public.study_replay_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.study_sessions(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_offset_ms INT NOT NULL CHECK (event_offset_ms >= 0),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_study_notebooks_student_lesson ON public.study_notebooks(student_id, lesson_id);
CREATE INDEX IF NOT EXISTS idx_study_code_drafts_student_lesson ON public.study_code_drafts(student_id, lesson_id);
CREATE INDEX IF NOT EXISTS idx_study_bookmarks_student_lesson ON public.study_bookmarks(student_id, lesson_id);
CREATE INDEX IF NOT EXISTS idx_study_annotations_student_lesson_page ON public.study_annotations(student_id, lesson_id, page_number);
CREATE INDEX IF NOT EXISTS idx_study_sessions_student_lesson ON public.study_sessions(student_id, lesson_id);
CREATE INDEX IF NOT EXISTS idx_study_replay_events_session_offset ON public.study_replay_events(session_id, event_offset_ms);

DROP TRIGGER IF EXISTS update_study_notebooks_modtime ON public.study_notebooks;
CREATE TRIGGER update_study_notebooks_modtime
BEFORE UPDATE ON public.study_notebooks
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS update_study_code_drafts_modtime ON public.study_code_drafts;
CREATE TRIGGER update_study_code_drafts_modtime
BEFORE UPDATE ON public.study_code_drafts
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS update_study_bookmarks_modtime ON public.study_bookmarks;
CREATE TRIGGER update_study_bookmarks_modtime
BEFORE UPDATE ON public.study_bookmarks
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS update_study_annotations_modtime ON public.study_annotations;
CREATE TRIGGER update_study_annotations_modtime
BEFORE UPDATE ON public.study_annotations
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.study_notebooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_code_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_annotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_replay_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Study notebooks readable by owner and guardians" ON public.study_notebooks;
DROP POLICY IF EXISTS "Study notebooks writable by owner" ON public.study_notebooks;
DROP POLICY IF EXISTS "Study code drafts readable by owner and guardians" ON public.study_code_drafts;
DROP POLICY IF EXISTS "Study code drafts writable by owner" ON public.study_code_drafts;
DROP POLICY IF EXISTS "Study bookmarks readable by owner and guardians" ON public.study_bookmarks;
DROP POLICY IF EXISTS "Study bookmarks writable by owner" ON public.study_bookmarks;
DROP POLICY IF EXISTS "Study annotations readable by owner and guardians" ON public.study_annotations;
DROP POLICY IF EXISTS "Study annotations writable by owner" ON public.study_annotations;
DROP POLICY IF EXISTS "Study sessions readable by owner and guardians" ON public.study_sessions;
DROP POLICY IF EXISTS "Study sessions writable by owner" ON public.study_sessions;
DROP POLICY IF EXISTS "Study replay events readable through authorized session" ON public.study_replay_events;
DROP POLICY IF EXISTS "Study replay events writable by owner" ON public.study_replay_events;

CREATE POLICY "Study notebooks readable by owner and guardians" ON public.study_notebooks
FOR SELECT TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
    OR public.is_parent_of_student(auth.uid(), student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    OR (
        public.current_user_role() = 'teacher'
        AND EXISTS (
            SELECT 1 FROM public.enrollments e
            JOIN public.group_teachers gt ON gt.group_id = e.group_id
            WHERE e.student_id = study_notebooks.student_id
              AND gt.teacher_id = public.get_teacher_id(auth.uid())
              AND e.status = 'active'
        )
    )
);

CREATE POLICY "Study notebooks writable by owner" ON public.study_notebooks
FOR ALL TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
) WITH CHECK (
    student_id = public.get_student_id(auth.uid())
    AND public.current_student_can_access_lesson(lesson_id)
);

CREATE POLICY "Study code drafts readable by owner and guardians" ON public.study_code_drafts
FOR SELECT TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
    OR public.is_parent_of_student(auth.uid(), student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

CREATE POLICY "Study code drafts writable by owner" ON public.study_code_drafts
FOR ALL TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
) WITH CHECK (
    student_id = public.get_student_id(auth.uid())
    AND public.current_student_can_access_lesson(lesson_id)
);

CREATE POLICY "Study bookmarks readable by owner and guardians" ON public.study_bookmarks
FOR SELECT TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
    OR public.is_parent_of_student(auth.uid(), student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

CREATE POLICY "Study bookmarks writable by owner" ON public.study_bookmarks
FOR ALL TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
) WITH CHECK (
    student_id = public.get_student_id(auth.uid())
    AND public.current_student_can_access_lesson(lesson_id)
);

CREATE POLICY "Study annotations readable by owner and guardians" ON public.study_annotations
FOR SELECT TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
    OR public.is_parent_of_student(auth.uid(), student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

CREATE POLICY "Study annotations writable by owner" ON public.study_annotations
FOR ALL TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
) WITH CHECK (
    student_id = public.get_student_id(auth.uid())
    AND public.current_student_can_access_lesson(lesson_id)
);

CREATE POLICY "Study sessions readable by owner and guardians" ON public.study_sessions
FOR SELECT TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
    OR public.is_parent_of_student(auth.uid(), student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
    OR (
        consent_teacher_replay
        AND public.current_user_role() = 'teacher'
        AND EXISTS (
            SELECT 1 FROM public.enrollments e
            JOIN public.group_teachers gt ON gt.group_id = e.group_id
            WHERE e.student_id = study_sessions.student_id
              AND gt.teacher_id = public.get_teacher_id(auth.uid())
              AND e.status = 'active'
        )
    )
);

CREATE POLICY "Study sessions writable by owner" ON public.study_sessions
FOR ALL TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
) WITH CHECK (
    student_id = public.get_student_id(auth.uid())
    AND public.current_student_can_access_lesson(lesson_id)
);

CREATE POLICY "Study replay events readable through authorized session" ON public.study_replay_events
FOR SELECT TO authenticated USING (
    EXISTS (
        SELECT 1 FROM public.study_sessions s
        WHERE s.id = study_replay_events.session_id
          AND (
              s.student_id = public.get_student_id(auth.uid())
              OR public.is_parent_of_student(auth.uid(), s.student_id)
              OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
              OR (s.consent_teacher_replay AND public.current_user_role() = 'teacher')
          )
    )
);

CREATE POLICY "Study replay events writable by owner" ON public.study_replay_events
FOR ALL TO authenticated USING (
    student_id = public.get_student_id(auth.uid())
) WITH CHECK (
    student_id = public.get_student_id(auth.uid())
    AND public.current_student_can_access_lesson(lesson_id)
);
