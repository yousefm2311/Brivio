-- Helpdesk runtime contract: tickets, replies, group routing, and RLS.

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL,
  assigned_teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'Normal'
    CHECK (priority IN ('Low', 'Normal', 'High', 'Urgent', 'low', 'normal', 'high', 'urgent')),
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'closed', 'pending')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Existing remote databases may already have support_tickets from an earlier
-- manual/schema attempt. CREATE TABLE IF NOT EXISTS will not add missing
-- columns, so normalize the table shape explicitly.
ALTER TABLE public.support_tickets
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS assigned_teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS subject TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'Normal',
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'open',
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE TABLE IF NOT EXISTS public.ticket_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.ticket_replies
  ADD COLUMN IF NOT EXISTS ticket_id UUID REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS message TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_support_tickets_user_id
ON public.support_tickets(user_id);

CREATE INDEX IF NOT EXISTS idx_support_tickets_group_id
ON public.support_tickets(group_id);

CREATE INDEX IF NOT EXISTS idx_ticket_replies_ticket_id
ON public.ticket_replies(ticket_id, created_at);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_replies ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.route_support_ticket()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := NOW();

  IF NEW.group_id IS NOT NULL AND NEW.assigned_teacher_id IS NULL THEN
    SELECT teacher_id
    INTO NEW.assigned_teacher_id
    FROM public.group_teachers
    WHERE group_id = NEW.group_id
      AND (is_primary = true OR role = 'primary')
      AND COALESCE(is_active, true) = true
      AND effective_from <= CURRENT_DATE
      AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
    ORDER BY is_primary DESC, effective_from DESC
    LIMIT 1;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_route_support_ticket ON public.support_tickets;
CREATE TRIGGER tr_route_support_ticket
BEFORE INSERT OR UPDATE ON public.support_tickets
FOR EACH ROW
EXECUTE FUNCTION public.route_support_ticket();

DROP POLICY IF EXISTS "Support tickets visible to participants" ON public.support_tickets;
CREATE POLICY "Support tickets visible to participants"
ON public.support_tickets FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
  OR assigned_teacher_id = public.current_teacher_id()
  OR (
    group_id IS NOT NULL
    AND public.current_teacher_assigned_to_group(group_id)
  )
);

DROP POLICY IF EXISTS "Users create own support tickets" ON public.support_tickets;
CREATE POLICY "Users create own support tickets"
ON public.support_tickets FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Support tickets updatable by staff and assigned teachers" ON public.support_tickets;
CREATE POLICY "Support tickets updatable by staff and assigned teachers"
ON public.support_tickets FOR UPDATE TO authenticated
USING (
  public.current_user_role() IN ('admin', 'staff', 'super_admin')
  OR assigned_teacher_id = public.current_teacher_id()
  OR (
    group_id IS NOT NULL
    AND public.current_teacher_assigned_to_group(group_id)
  )
)
WITH CHECK (
  public.current_user_role() IN ('admin', 'staff', 'super_admin')
  OR assigned_teacher_id = public.current_teacher_id()
  OR (
    group_id IS NOT NULL
    AND public.current_teacher_assigned_to_group(group_id)
  )
);

DROP POLICY IF EXISTS "Ticket replies visible to ticket participants" ON public.ticket_replies;
CREATE POLICY "Ticket replies visible to ticket participants"
ON public.ticket_replies FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.support_tickets st
    WHERE st.id = ticket_replies.ticket_id
      AND (
        st.user_id = auth.uid()
        OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
        OR st.assigned_teacher_id = public.current_teacher_id()
        OR (
          st.group_id IS NOT NULL
          AND public.current_teacher_assigned_to_group(st.group_id)
        )
      )
  )
);

DROP POLICY IF EXISTS "Ticket participants can add replies" ON public.ticket_replies;
CREATE POLICY "Ticket participants can add replies"
ON public.ticket_replies FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.support_tickets st
    WHERE st.id = ticket_replies.ticket_id
      AND st.status <> 'closed'
      AND (
        st.user_id = auth.uid()
        OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
        OR st.assigned_teacher_id = public.current_teacher_id()
        OR (
          st.group_id IS NOT NULL
          AND public.current_teacher_assigned_to_group(st.group_id)
        )
      )
  )
);

GRANT SELECT, INSERT, UPDATE ON public.support_tickets TO authenticated;
GRANT SELECT, INSERT ON public.ticket_replies TO authenticated;

NOTIFY pgrst, 'reload schema';
