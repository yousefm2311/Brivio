-- Add group_id to support_tickets
ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL;

-- Create ticket_replies table
CREATE TABLE IF NOT EXISTS public.ticket_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.ticket_replies ENABLE ROW LEVEL SECURITY;

-- Allow users who can view/update the ticket to view/reply to the ticket
-- For simplicity, if we assume support_tickets RLS is already correct, we can let owner view/insert
CREATE POLICY "Enable read access for ticket owners/admins" ON public.ticket_replies
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.support_tickets t 
      WHERE t.id = ticket_replies.ticket_id 
        AND t.user_id = auth.uid()
    ) OR 
    (auth.jwt() ->> 'role' = 'admin') OR
    (auth.jwt() ->> 'role' = 'teacher') OR
    (auth.jwt() ->> 'role' = 'parent')
  );

CREATE POLICY "Enable insert access for ticket owners/admins" ON public.ticket_replies
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.support_tickets t 
      WHERE t.id = ticket_replies.ticket_id 
        AND t.user_id = auth.uid()
    ) OR 
    (auth.jwt() ->> 'role' = 'admin') OR
    (auth.jwt() ->> 'role' = 'teacher') OR
    (auth.jwt() ->> 'role' = 'parent')
  );
