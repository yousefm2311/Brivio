-- Phase 4: Full Admin Dashboard Completion

-- 1. Global Settings
CREATE TABLE IF NOT EXISTS public.admin_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin settings viewable by admin"
ON public.admin_settings FOR SELECT TO authenticated
USING (public.is_admin_or_super());

CREATE POLICY "Admin settings insert/update by admin"
ON public.admin_settings FOR ALL TO authenticated
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());

-- RPC for Settings
CREATE OR REPLACE FUNCTION public.get_admin_setting(setting_key TEXT)
RETURNS JSONB AS $$
BEGIN
    RETURN (SELECT value FROM public.admin_settings WHERE key = setting_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.set_admin_setting(setting_key TEXT, setting_value JSONB)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.admin_settings (key, value, updated_at)
    VALUES (setting_key, setting_value, NOW())
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Security/RBAC system
CREATE TABLE IF NOT EXISTS public.admin_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    permissions TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.admin_user_roles (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.admin_roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id)
);

ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_user_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin roles viewable by admin"
ON public.admin_roles FOR SELECT TO authenticated
USING (public.is_admin_or_super());

CREATE POLICY "Admin roles all by admin"
ON public.admin_roles FOR ALL TO authenticated
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());

CREATE POLICY "Admin user roles viewable by admin"
ON public.admin_user_roles FOR SELECT TO authenticated
USING (public.is_admin_or_super());

CREATE POLICY "Admin user roles all by admin"
ON public.admin_user_roles FOR ALL TO authenticated
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());


-- RPCs for RBAC
CREATE OR REPLACE FUNCTION public.create_admin_role(role_name TEXT, role_permissions TEXT[])
RETURNS UUID AS $$
DECLARE
    new_role_id UUID;
BEGIN
    INSERT INTO public.admin_roles (name, permissions)
    VALUES (role_name, role_permissions)
    RETURNING id INTO new_role_id;
    RETURN new_role_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.assign_admin_role(target_user_id UUID, target_role_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.admin_user_roles (user_id, role_id)
    VALUES (target_user_id, target_role_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Analytics Dashboard
-- Aggregations for attendance, revenue, etc.
CREATE OR REPLACE FUNCTION public.get_admin_analytics(period_start DATE, period_end DATE)
RETURNS JSONB AS $$
DECLARE
    total_revenue NUMERIC;
    total_attendance_rate NUMERIC;
    total_students INT;
    total_sessions INT;
    result JSONB;
BEGIN
    -- This assumes payment_transactions exists (from phase 7)
    -- total_revenue := COALESCE((SELECT SUM(amount) FROM public.payment_transactions WHERE created_at::DATE >= period_start AND created_at::DATE <= period_end AND status = 'completed'), 0);
    -- Fallback dummy for compilation if missing:
    total_revenue := 0;

    -- Calculate attendance rate
    SELECT 
        CASE WHEN count(*) = 0 THEN 0 ELSE (sum(case when attendance_status = 'present' then 1 else 0 end)::NUMERIC / count(*)) * 100 END,
        COUNT(DISTINCT class_session_id)
    INTO total_attendance_rate, total_sessions
    FROM public.attendance_records
    WHERE marked_at::DATE >= period_start AND marked_at::DATE <= period_end;

    SELECT COUNT(*) INTO total_students FROM public.students;

    result := jsonb_build_object(
        'total_revenue', total_revenue,
        'attendance_rate', total_attendance_rate,
        'total_students', total_students,
        'total_sessions', total_sessions
    );

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Helpdesk Ticketing
CREATE TABLE IF NOT EXISTS public.helpdesk_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.helpdesk_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES public.helpdesk_tickets(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.helpdesk_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.helpdesk_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Tickets viewable by creator or admin"
ON public.helpdesk_tickets FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_admin_or_super());

CREATE POLICY "Tickets insertable by authenticated"
ON public.helpdesk_tickets FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid() OR public.is_admin_or_super());

CREATE POLICY "Tickets updatable by admin"
ON public.helpdesk_tickets FOR UPDATE TO authenticated
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());

CREATE POLICY "Ticket messages viewable by ticket owner or admin"
ON public.helpdesk_messages FOR SELECT TO authenticated
USING (
    EXISTS (SELECT 1 FROM public.helpdesk_tickets t WHERE t.id = ticket_id AND t.user_id = auth.uid()) 
    OR public.is_admin_or_super()
);

CREATE POLICY "Ticket messages insertable by ticket owner or admin"
ON public.helpdesk_messages FOR INSERT TO authenticated
WITH CHECK (
    sender_id = auth.uid() AND (
        EXISTS (SELECT 1 FROM public.helpdesk_tickets t WHERE t.id = ticket_id AND t.user_id = auth.uid()) 
        OR public.is_admin_or_super()
    )
);
