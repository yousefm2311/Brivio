-- parent_core.sql
-- Core tables for Parent Portal functionality

-- Table to map parents to students
CREATE TABLE IF NOT EXISTS public.parent_student_links (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    parent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    linked_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'pending', 'inactive')),
    UNIQUE(parent_id, student_id)
);

-- Enable RLS
ALTER TABLE public.parent_student_links ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Parents can view their own links"
    ON public.parent_student_links FOR SELECT
    USING (auth.uid() = parent_id);

CREATE POLICY "Parents can create links"
    ON public.parent_student_links FOR INSERT
    WITH CHECK (auth.uid() = parent_id);
