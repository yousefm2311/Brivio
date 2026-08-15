-- Helpdesk delivery hardening: keep ticket/reply writes behind stable RPCs so
-- student, parent, teacher, staff, and admin screens all use one runtime contract.

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

UPDATE public.support_tickets
SET priority = COALESCE(NULLIF(priority, ''), 'Normal'),
    status = COALESCE(NULLIF(status, ''), 'open'),
    subject = COALESCE(NULLIF(subject, ''), 'Support request'),
    description = COALESCE(NULLIF(description, ''), 'No description provided.'),
    updated_at = COALESCE(updated_at, NOW()),
    created_at = COALESCE(created_at, NOW());

ALTER TABLE public.support_tickets
  ALTER COLUMN user_id SET NOT NULL,
  ALTER COLUMN subject SET NOT NULL,
  ALTER COLUMN description SET NOT NULL,
  ALTER COLUMN priority SET NOT NULL,
  ALTER COLUMN status SET NOT NULL,
  ALTER COLUMN created_at SET NOT NULL,
  ALTER COLUMN updated_at SET NOT NULL;

ALTER TABLE public.support_tickets
  DROP CONSTRAINT IF EXISTS support_tickets_priority_check,
  DROP CONSTRAINT IF EXISTS support_tickets_status_check;

ALTER TABLE public.support_tickets
  ADD CONSTRAINT support_tickets_priority_check
    CHECK (priority IN ('Low', 'Normal', 'High', 'Urgent', 'low', 'normal', 'high', 'urgent')),
  ADD CONSTRAINT support_tickets_status_check
    CHECK (status IN ('open', 'in_progress', 'resolved', 'closed', 'pending'));

ALTER TABLE public.ticket_replies
  ADD COLUMN IF NOT EXISTS ticket_id UUID REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS message TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

UPDATE public.ticket_replies
SET message = COALESCE(NULLIF(message, ''), '...'),
    created_at = COALESCE(created_at, NOW());

ALTER TABLE public.ticket_replies
  ALTER COLUMN ticket_id SET NOT NULL,
  ALTER COLUMN user_id SET NOT NULL,
  ALTER COLUMN message SET NOT NULL,
  ALTER COLUMN created_at SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_support_tickets_assigned_teacher_id
ON public.support_tickets(assigned_teacher_id);

CREATE OR REPLACE FUNCTION public.current_user_can_access_support_ticket(target_ticket_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  st public.support_tickets%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  SELECT * INTO st
  FROM public.support_tickets
  WHERE id = target_ticket_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF st.user_id = auth.uid()
     OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
     OR st.assigned_teacher_id = public.current_teacher_id()
     OR (
       st.group_id IS NOT NULL
       AND public.current_teacher_assigned_to_group(st.group_id)
     ) THEN
    RETURN true;
  END IF;

  IF st.group_id IS NOT NULL THEN
    RETURN EXISTS (
      SELECT 1
      FROM public.parents p
      JOIN public.parent_students ps ON ps.parent_id = p.id
      JOIN public.enrollments e ON e.student_id = ps.student_id
      WHERE p.profile_id = auth.uid()
        AND e.group_id = st.group_id
        AND e.status = 'active'
    );
  END IF;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.current_user_can_create_support_ticket_for_group(target_group_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  IF target_group_id IS NULL
     OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
     OR public.current_student_enrolled_in_group(target_group_id)
     OR public.current_teacher_assigned_to_group(target_group_id) THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.parents p
    JOIN public.parent_students ps ON ps.parent_id = p.id
    JOIN public.enrollments e ON e.student_id = ps.student_id
    WHERE p.profile_id = auth.uid()
      AND e.group_id = target_group_id
      AND e.status = 'active'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.route_support_ticket()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := NOW();

  IF NEW.group_id IS NOT NULL AND NEW.assigned_teacher_id IS NULL THEN
    SELECT gt.teacher_id
    INTO NEW.assigned_teacher_id
    FROM public.group_teachers gt
    WHERE gt.group_id = NEW.group_id
      AND (gt.is_primary = true OR gt.role = 'primary')
      AND COALESCE(gt.is_active, true) = true
      AND gt.effective_from <= CURRENT_DATE
      AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
    ORDER BY gt.is_primary DESC, gt.effective_from DESC
    LIMIT 1;

    IF NEW.assigned_teacher_id IS NULL THEN
      SELECT g.teacher_id
      INTO NEW.assigned_teacher_id
      FROM public.groups g
      WHERE g.id = NEW.group_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_route_support_ticket ON public.support_tickets;
CREATE TRIGGER tr_route_support_ticket
BEFORE INSERT OR UPDATE ON public.support_tickets
FOR EACH ROW
EXECUTE FUNCTION public.route_support_ticket();

CREATE OR REPLACE FUNCTION public.create_support_ticket(
  p_subject TEXT,
  p_description TEXT,
  p_priority TEXT DEFAULT 'Normal',
  p_group_id UUID DEFAULT NULL
)
RETURNS public.support_tickets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  inserted_ticket public.support_tickets%ROWTYPE;
  clean_priority TEXT := COALESCE(NULLIF(trim(p_priority), ''), 'Normal');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.current_user_can_create_support_ticket_for_group(p_group_id) THEN
    RAISE EXCEPTION 'You are not allowed to create a ticket for this group';
  END IF;

  IF NULLIF(trim(p_subject), '') IS NULL THEN
    RAISE EXCEPTION 'Ticket subject is required';
  END IF;

  IF NULLIF(trim(p_description), '') IS NULL THEN
    RAISE EXCEPTION 'Ticket description is required';
  END IF;

  IF clean_priority NOT IN ('Low', 'Normal', 'High', 'Urgent', 'low', 'normal', 'high', 'urgent') THEN
    clean_priority := 'Normal';
  END IF;

  INSERT INTO public.support_tickets (
    user_id,
    group_id,
    subject,
    description,
    priority,
    status
  )
  VALUES (
    auth.uid(),
    p_group_id,
    trim(p_subject),
    trim(p_description),
    clean_priority,
    'open'
  )
  RETURNING * INTO inserted_ticket;

  RETURN inserted_ticket;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_ticket_reply(
  p_ticket_id UUID,
  p_message TEXT
)
RETURNS public.ticket_replies
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  inserted_reply public.ticket_replies%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NULLIF(trim(p_message), '') IS NULL THEN
    RAISE EXCEPTION 'Reply message is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.support_tickets st
    WHERE st.id = p_ticket_id
      AND st.status <> 'closed'
  ) THEN
    RAISE EXCEPTION 'Ticket is closed or does not exist';
  END IF;

  IF NOT public.current_user_can_access_support_ticket(p_ticket_id) THEN
    RAISE EXCEPTION 'You are not allowed to reply to this ticket';
  END IF;

  INSERT INTO public.ticket_replies (ticket_id, user_id, message)
  VALUES (p_ticket_id, auth.uid(), trim(p_message))
  RETURNING * INTO inserted_reply;

  UPDATE public.support_tickets
  SET updated_at = NOW(),
      status = CASE WHEN status = 'open' THEN 'in_progress' ELSE status END
  WHERE id = p_ticket_id;

  RETURN inserted_reply;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_support_ticket_status(
  p_ticket_id UUID,
  p_status TEXT
)
RETURNS public.support_tickets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_ticket public.support_tickets%ROWTYPE;
  clean_status TEXT := COALESCE(NULLIF(trim(p_status), ''), 'open');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF clean_status NOT IN ('open', 'in_progress', 'resolved', 'closed', 'pending') THEN
    RAISE EXCEPTION 'Invalid ticket status';
  END IF;

  IF NOT (
    public.current_user_role() IN ('admin', 'staff', 'super_admin')
    OR EXISTS (
      SELECT 1
      FROM public.support_tickets st
      WHERE st.id = p_ticket_id
        AND (
          st.assigned_teacher_id = public.current_teacher_id()
          OR (
            st.group_id IS NOT NULL
            AND public.current_teacher_assigned_to_group(st.group_id)
          )
        )
    )
  ) THEN
    RAISE EXCEPTION 'You are not allowed to update this ticket';
  END IF;

  UPDATE public.support_tickets
  SET status = clean_status,
      updated_at = NOW()
  WHERE id = p_ticket_id
  RETURNING * INTO updated_ticket;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ticket not found';
  END IF;

  RETURN updated_ticket;
END;
$$;

DROP POLICY IF EXISTS "Support tickets visible to participants" ON public.support_tickets;
CREATE POLICY "Support tickets visible to participants"
ON public.support_tickets FOR SELECT TO authenticated
USING (public.current_user_can_access_support_ticket(id));

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
USING (public.current_user_can_access_support_ticket(ticket_id));

DROP POLICY IF EXISTS "Ticket participants can add replies" ON public.ticket_replies;
CREATE POLICY "Ticket participants can add replies"
ON public.ticket_replies FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND public.current_user_can_access_support_ticket(ticket_id)
);

GRANT EXECUTE ON FUNCTION public.current_user_can_access_support_ticket(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_create_support_ticket_for_group(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_support_ticket(TEXT, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_ticket_reply(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_support_ticket_status(UUID, TEXT) TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.support_tickets TO authenticated;
GRANT SELECT, INSERT ON public.ticket_replies TO authenticated;

NOTIFY pgrst, 'reload schema';
