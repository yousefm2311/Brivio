-- Migration: 20260809001300_pdf_freehand_drawings.sql
-- Description: Per-page freehand drawing overlay data for student PDF study.

CREATE TABLE IF NOT EXISTS public.study_pdf_drawings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  page_number INT NOT NULL CHECK (page_number > 0),
  strokes JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_study_pdf_drawing_page UNIQUE (student_id, lesson_id, page_number)
);

CREATE INDEX IF NOT EXISTS idx_study_pdf_drawings_student_lesson
ON public.study_pdf_drawings(student_id, lesson_id, page_number);

ALTER TABLE public.study_pdf_drawings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Study PDF drawings readable by owner guardians and staff" ON public.study_pdf_drawings;
CREATE POLICY "Study PDF drawings readable by owner guardians and staff"
ON public.study_pdf_drawings FOR SELECT TO authenticated USING (
  student_id = public.current_student_id()
  OR public.current_parent_has_student(student_id)
  OR public.current_user_role() IN ('admin', 'staff', 'super_admin', 'teacher')
);

DROP POLICY IF EXISTS "Study PDF drawings writable by owner" ON public.study_pdf_drawings;
CREATE POLICY "Study PDF drawings writable by owner"
ON public.study_pdf_drawings FOR ALL TO authenticated USING (
  student_id = public.current_student_id()
)
WITH CHECK (
  student_id = public.current_student_id()
  AND public.current_student_can_access_lesson(lesson_id)
);

NOTIFY pgrst, 'reload schema';
