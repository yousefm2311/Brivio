-- Migration: Create app_notifications table
-- This resolves the 42P01 error when grading homework/exams.

CREATE TABLE IF NOT EXISTS public.app_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- e.g., 'assignment', 'announcement', 'grade'
    reference_id UUID, -- Optional link to homework_id, exam_id, etc.
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;

-- Users can read their own notifications
CREATE POLICY "Users can read their own notifications"
    ON public.app_notifications FOR SELECT
    USING (auth.uid() = user_id);

-- System/RPC can insert notifications
-- We allow authenticated users to insert if they are a teacher grading, handled by SECURITY DEFINER on RPCs, 
-- but just in case, we grant INSERT to authenticated.
CREATE POLICY "System can insert notifications"
    ON public.app_notifications FOR INSERT
    WITH CHECK (true);

-- Users can update their own notifications (e.g. mark as read)
CREATE POLICY "Users can update their own notifications"
    ON public.app_notifications FOR UPDATE
    USING (auth.uid() = user_id);

-- Grants
GRANT SELECT, INSERT, UPDATE ON public.app_notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.app_notifications TO service_role;
