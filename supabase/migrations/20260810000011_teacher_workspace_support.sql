-- Migration: 20260810000011_teacher_workspace_support.sql
-- Description: Adds tables for teacher study annotations and an RPC to fetch them for students.

-- 1. Create Teacher Study Annotations table
CREATE TABLE IF NOT EXISTS public.teacher_study_annotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    page_number INT NOT NULL CHECK (page_number > 0),
    annotation_type study_annotation_type NOT NULL,
    color TEXT,
    geometry JSONB NOT NULL DEFAULT '{}'::jsonb,
    content TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_teacher_study_annotations_lesson_page ON public.teacher_study_annotations(lesson_id, page_number);
CREATE INDEX IF NOT EXISTS idx_teacher_study_annotations_teacher ON public.teacher_study_annotations(teacher_id);

ALTER TABLE public.teacher_study_annotations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teachers can insert their own annotations" ON public.teacher_study_annotations;
CREATE POLICY "Teachers can insert their own annotations"
    ON public.teacher_study_annotations FOR INSERT TO authenticated
    WITH CHECK (teacher_id = auth.uid());

DROP POLICY IF EXISTS "Teachers can update their own annotations" ON public.teacher_study_annotations;
CREATE POLICY "Teachers can update their own annotations"
    ON public.teacher_study_annotations FOR UPDATE TO authenticated
    USING (teacher_id = auth.uid()) WITH CHECK (teacher_id = auth.uid());

DROP POLICY IF EXISTS "Teachers can delete their own annotations" ON public.teacher_study_annotations;
CREATE POLICY "Teachers can delete their own annotations"
    ON public.teacher_study_annotations FOR DELETE TO authenticated
    USING (teacher_id = auth.uid());

DROP POLICY IF EXISTS "Anyone can read teacher annotations" ON public.teacher_study_annotations;
CREATE POLICY "Anyone can read teacher annotations"
    ON public.teacher_study_annotations FOR SELECT TO authenticated
    USING (true);

-- 2. Create Teacher PDF Drawings table
CREATE TABLE IF NOT EXISTS public.teacher_study_pdf_drawings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    page_number INT NOT NULL CHECK (page_number > 0),
    strokes JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_teacher_pdf_drawing_page UNIQUE (teacher_id, lesson_id, page_number)
);

ALTER TABLE public.teacher_study_pdf_drawings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teachers can insert their own drawings" ON public.teacher_study_pdf_drawings;
CREATE POLICY "Teachers can insert their own drawings"
    ON public.teacher_study_pdf_drawings FOR INSERT TO authenticated
    WITH CHECK (teacher_id = auth.uid());

DROP POLICY IF EXISTS "Teachers can update their own drawings" ON public.teacher_study_pdf_drawings;
CREATE POLICY "Teachers can update their own drawings"
    ON public.teacher_study_pdf_drawings FOR UPDATE TO authenticated
    USING (teacher_id = auth.uid()) WITH CHECK (teacher_id = auth.uid());

DROP POLICY IF EXISTS "Teachers can delete their own drawings" ON public.teacher_study_pdf_drawings;
CREATE POLICY "Teachers can delete their own drawings"
    ON public.teacher_study_pdf_drawings FOR DELETE TO authenticated
    USING (teacher_id = auth.uid());

DROP POLICY IF EXISTS "Anyone can read teacher drawings" ON public.teacher_study_pdf_drawings;
CREATE POLICY "Anyone can read teacher drawings"
    ON public.teacher_study_pdf_drawings FOR SELECT TO authenticated
    USING (true);

-- 3. Create RPCs for students to fetch their teachers' annotations and drawings for a specific lesson
CREATE OR REPLACE FUNCTION get_student_teacher_study_annotations(p_lesson_id UUID, p_student_id UUID)
RETURNS SETOF public.teacher_study_annotations AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT tsa.*
    FROM public.teacher_study_annotations tsa
    JOIN public.group_teachers gt ON tsa.teacher_id = gt.teacher_id
    JOIN public.group_students gs ON gt.group_id = gs.group_id
    WHERE tsa.lesson_id = p_lesson_id
      AND gs.student_id = (SELECT id FROM public.students WHERE profile_id = p_student_id LIMIT 1)
      AND gt.is_active = true
      AND gs.status = 'active'
      AND (gt.effective_end_date IS NULL OR gt.effective_end_date > NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_student_teacher_study_pdf_drawings(p_lesson_id UUID, p_student_id UUID)
RETURNS SETOF public.teacher_study_pdf_drawings AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT tsd.*
    FROM public.teacher_study_pdf_drawings tsd
    JOIN public.group_teachers gt ON tsd.teacher_id = gt.teacher_id
    JOIN public.group_students gs ON gt.group_id = gs.group_id
    WHERE tsd.lesson_id = p_lesson_id
      AND gs.student_id = (SELECT id FROM public.students WHERE profile_id = p_student_id LIMIT 1)
      AND gt.is_active = true
      AND gs.status = 'active'
      AND (gt.effective_end_date IS NULL OR gt.effective_end_date > NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
