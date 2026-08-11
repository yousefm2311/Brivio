-- Phase 1.3: Helpdesk Module Support Tickets Schema

CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger to update 'updated_at'
CREATE OR REPLACE FUNCTION update_support_tickets_modtime()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_support_tickets_modtime ON public.support_tickets;

CREATE TRIGGER trigger_update_support_tickets_modtime
    BEFORE UPDATE ON public.support_tickets
    FOR EACH ROW
    EXECUTE FUNCTION update_support_tickets_modtime();

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Support tickets viewable by creator or admin"
ON public.support_tickets FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_admin_or_super());

CREATE POLICY "Support tickets insertable by authenticated"
ON public.support_tickets FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid() OR public.is_admin_or_super());

CREATE POLICY "Support tickets updatable by admin"
ON public.support_tickets FOR UPDATE TO authenticated
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());
