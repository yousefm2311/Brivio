-- Migration: 20260809001100_payment_gated_access.sql
-- Description: Gate student learning content until cash payment or exemption is recorded.

ALTER TABLE public.enrollments
  ADD COLUMN IF NOT EXISTS access_status TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'paid',
  ADD COLUMN IF NOT EXISTS base_price_minor BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_minor BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS final_price_minor BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS activation_invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS payment_exempt BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS payment_exemption_reason TEXT,
  ADD COLUMN IF NOT EXISTS activated_at TIMESTAMPTZ;

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS enrollment_id UUID REFERENCES public.enrollments(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'enrollments_access_status_check'
      AND conrelid = 'public.enrollments'::regclass
  ) THEN
    ALTER TABLE public.enrollments
      ADD CONSTRAINT enrollments_access_status_check
      CHECK (access_status IN ('pending_payment', 'active', 'blocked', 'expired'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'enrollments_payment_status_check'
      AND conrelid = 'public.enrollments'::regclass
  ) THEN
    ALTER TABLE public.enrollments
      ADD CONSTRAINT enrollments_payment_status_check
      CHECK (payment_status IN ('pending_payment', 'partial', 'paid', 'exempt', 'cancelled'));
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_enrollments_student_access
ON public.enrollments(student_id, access_status, payment_status);

CREATE INDEX IF NOT EXISTS idx_invoices_enrollment
ON public.invoices(enrollment_id);

CREATE OR REPLACE FUNCTION public.enrollment_has_learning_access(p_enrollment_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.enrollments e
    WHERE e.id = p_enrollment_id
      AND e.status = 'active'
      AND e.access_status = 'active'
      AND (
        e.payment_status IN ('paid', 'exempt')
        OR e.payment_exempt = true
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.student_has_paid_group_access(
  p_student_id UUID,
  p_group_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.enrollments e
    WHERE e.student_id = p_student_id
      AND e.group_id = p_group_id
      AND public.enrollment_has_learning_access(e.id)
  );
$$;

CREATE OR REPLACE FUNCTION public.notify_payment_required(
  p_student_id UUID,
  p_group_id UUID,
  p_invoice_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_profile UUID;
  v_group_name TEXT;
  v_parent_profile UUID;
BEGIN
  SELECT s.profile_id INTO v_student_profile
  FROM public.students s
  WHERE s.id = p_student_id;

  SELECT COALESCE(g.name, 'Group') INTO v_group_name
  FROM public.groups g
  WHERE g.id = p_group_id;

  IF v_student_profile IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, notification_type, title, body, data)
    VALUES (
      v_student_profile,
      'payment_required',
      'Payment required',
      'Payment is required to activate ' || COALESCE(v_group_name, 'your group') || '.',
      jsonb_build_object('student_id', p_student_id, 'group_id', p_group_id, 'invoice_id', p_invoice_id)
    );
  END IF;

  FOR v_parent_profile IN
    SELECT p.profile_id
    FROM public.parent_students ps
    JOIN public.parents p ON p.id = ps.parent_id
    WHERE ps.student_id = p_student_id
  LOOP
    INSERT INTO public.notifications (user_id, notification_type, title, body, data)
    VALUES (
      v_parent_profile,
      'payment_required',
      'Payment required',
      'A new group requires cash payment before content is activated.',
      jsonb_build_object('student_id', p_student_id, 'group_id', p_group_id, 'invoice_id', p_invoice_id)
    );
  END LOOP;
EXCEPTION WHEN undefined_table OR undefined_column THEN
  RETURN;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_payment_confirmed(
  p_student_id UUID,
  p_group_id UUID,
  p_invoice_id UUID,
  p_receipt_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_profile UUID;
  v_parent_profile UUID;
BEGIN
  SELECT s.profile_id INTO v_student_profile
  FROM public.students s
  WHERE s.id = p_student_id;

  IF v_student_profile IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, notification_type, title, body, data)
    VALUES (
      v_student_profile,
      'payment_confirmed',
      'Payment confirmed',
      'Cash payment was recorded and your group content is now active.',
      jsonb_build_object('student_id', p_student_id, 'group_id', p_group_id, 'invoice_id', p_invoice_id, 'receipt_id', p_receipt_id)
    );
  END IF;

  FOR v_parent_profile IN
    SELECT p.profile_id
    FROM public.parent_students ps
    JOIN public.parents p ON p.id = ps.parent_id
    WHERE ps.student_id = p_student_id
  LOOP
    INSERT INTO public.notifications (user_id, notification_type, title, body, data)
    VALUES (
      v_parent_profile,
      'payment_confirmed',
      'Payment confirmed',
      'Cash payment was recorded for your child and the group is now active.',
      jsonb_build_object('student_id', p_student_id, 'group_id', p_group_id, 'invoice_id', p_invoice_id, 'receipt_id', p_receipt_id)
    );
  END LOOP;
EXCEPTION WHEN undefined_table OR undefined_column THEN
  RETURN;
END;
$$;

CREATE OR REPLACE FUNCTION public.enroll_student_in_group(
  p_student_id UUID,
  p_group_id UUID,
  p_total_minor BIGINT DEFAULT NULL,
  p_discount_minor BIGINT DEFAULT 0,
  p_currency TEXT DEFAULT 'EGP',
  p_due_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  g_rec RECORD;
  current_active_count INT;
  s_status TEXT;
  v_enrollment_id UUID;
  v_invoice_id UUID;
  v_final_minor BIGINT;
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('enrollments.manage')
    OR public.has_permission('groups.manage')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to enroll student' USING ERRCODE = '42501';
  END IF;

  SELECT status INTO s_status FROM public.students WHERE id = p_student_id;
  IF s_status IS NULL THEN
    RAISE EXCEPTION 'Student record not found' USING ERRCODE = 'P0002';
  END IF;
  IF s_status <> 'active' THEN
    RAISE EXCEPTION 'Cannot enroll inactive student' USING ERRCODE = '22023';
  END IF;

  SELECT id, name, max_capacity, capacity, status INTO g_rec
  FROM public.groups
  WHERE id = p_group_id
  FOR UPDATE;

  IF g_rec.id IS NULL THEN
    RAISE EXCEPTION 'Group record not found' USING ERRCODE = 'P0002';
  END IF;
  IF g_rec.status <> 'active' THEN
    RAISE EXCEPTION 'Cannot enroll into inactive group' USING ERRCODE = '22023';
  END IF;

  SELECT COUNT(*)::INT INTO current_active_count
  FROM public.enrollments
  WHERE group_id = p_group_id AND status = 'active';

  IF COALESCE(g_rec.max_capacity, g_rec.capacity) IS NOT NULL
     AND current_active_count >= COALESCE(g_rec.max_capacity, g_rec.capacity)
     AND NOT EXISTS (
       SELECT 1 FROM public.enrollments
       WHERE student_id = p_student_id AND group_id = p_group_id AND status = 'active'
     ) THEN
    RAISE EXCEPTION 'Group capacity exceeded' USING ERRCODE = '54000';
  END IF;

  v_final_minor := GREATEST(0, COALESCE(p_total_minor, 0) - GREATEST(0, COALESCE(p_discount_minor, 0)));

  INSERT INTO public.enrollments (
    student_id,
    group_id,
    status,
    start_date,
    access_status,
    payment_status,
    base_price_minor,
    discount_minor,
    final_price_minor,
    payment_exempt,
    activated_at
  )
  VALUES (
    p_student_id,
    p_group_id,
    'active',
    CURRENT_DATE,
    CASE WHEN v_final_minor > 0 THEN 'pending_payment' ELSE 'active' END,
    CASE WHEN v_final_minor > 0 THEN 'pending_payment' ELSE 'exempt' END,
    GREATEST(0, COALESCE(p_total_minor, 0)),
    GREATEST(0, COALESCE(p_discount_minor, 0)),
    v_final_minor,
    v_final_minor = 0,
    CASE WHEN v_final_minor = 0 THEN NOW() ELSE NULL END
  )
  ON CONFLICT (student_id, group_id) WHERE status = 'active' DO UPDATE SET
    start_date = CURRENT_DATE,
    end_date = NULL,
    access_status = EXCLUDED.access_status,
    payment_status = EXCLUDED.payment_status,
    base_price_minor = EXCLUDED.base_price_minor,
    discount_minor = EXCLUDED.discount_minor,
    final_price_minor = EXCLUDED.final_price_minor,
    payment_exempt = EXCLUDED.payment_exempt,
    activated_at = EXCLUDED.activated_at,
    updated_at = NOW()
  RETURNING id INTO v_enrollment_id;

  IF v_final_minor > 0 THEN
    INSERT INTO public.invoices (
      student_id,
      enrollment_id,
      group_id,
      currency,
      subtotal_minor,
      discount_minor,
      total_minor,
      amount_paid_minor,
      status,
      due_at
    )
    VALUES (
      p_student_id,
      v_enrollment_id,
      p_group_id,
      COALESCE(NULLIF(p_currency, ''), 'EGP'),
      GREATEST(0, COALESCE(p_total_minor, 0)),
      GREATEST(0, COALESCE(p_discount_minor, 0)),
      v_final_minor,
      0,
      'issued',
      COALESCE(p_due_at, NOW() + INTERVAL '7 days')
    )
    RETURNING id INTO v_invoice_id;

    INSERT INTO public.invoice_items (
      invoice_id,
      description,
      quantity,
      unit_amount_minor,
      total_minor
    )
    VALUES (
      v_invoice_id,
      'Group enrollment: ' || COALESCE(g_rec.name, p_group_id::TEXT),
      1,
      v_final_minor,
      v_final_minor
    );

    UPDATE public.enrollments
    SET activation_invoice_id = v_invoice_id,
        updated_at = NOW()
    WHERE id = v_enrollment_id;

    PERFORM public.notify_payment_required(p_student_id, p_group_id, v_invoice_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'enrollment_id', v_enrollment_id,
    'invoice_id', v_invoice_id,
    'requires_payment', v_final_minor > 0,
    'access_status', CASE WHEN v_final_minor > 0 THEN 'pending_payment' ELSE 'active' END,
    'message', CASE
      WHEN v_final_minor > 0 THEN 'Student enrolled. Content is pending cash payment.'
      ELSE 'Student enrolled with payment exemption.'
    END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.activate_paid_enrollment_for_invoice(p_invoice_id UUID, p_receipt_id UUID DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  inv RECORD;
BEGIN
  SELECT * INTO inv
  FROM public.invoices
  WHERE id = p_invoice_id
    AND status = 'paid';

  IF inv.id IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.enrollments
  SET access_status = 'active',
      payment_status = 'paid',
      activated_at = COALESCE(activated_at, NOW()),
      updated_at = NOW()
  WHERE id = inv.enrollment_id
     OR (
       inv.enrollment_id IS NULL
       AND inv.group_id IS NOT NULL
       AND student_id = inv.student_id
       AND group_id = inv.group_id
       AND status = 'active'
     );

  IF inv.group_id IS NOT NULL THEN
    PERFORM public.notify_payment_confirmed(inv.student_id, inv.group_id, inv.id, p_receipt_id);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_verified_payment(
    p_attempt_id UUID,
    p_provider_tx_id TEXT,
    p_amount_minor BIGINT,
    p_currency TEXT DEFAULT 'EGP'
)
RETURNS JSONB AS $$
DECLARE
    att RECORD;
    inv RECORD;
    new_paid BIGINT;
    new_status TEXT;
    tx_id UUID;
    rec_id UUID;
BEGIN
    SELECT * INTO att FROM public.payment_attempts WHERE id = p_attempt_id FOR UPDATE;
    IF att.id IS NULL THEN
        RAISE EXCEPTION 'Payment attempt not found' USING ERRCODE = '44000';
    END IF;

    SELECT * INTO inv FROM public.invoices WHERE id = att.invoice_id FOR UPDATE;

    INSERT INTO public.payment_transactions (
        invoice_id, payment_attempt_id, provider, provider_transaction_id, amount_minor, currency, status
    )
    VALUES (
        inv.id, att.id, att.provider, p_provider_tx_id, p_amount_minor, p_currency, 'succeeded'
    )
    ON CONFLICT (provider_transaction_id) DO NOTHING
    RETURNING id INTO tx_id;

    IF tx_id IS NULL THEN
        SELECT id INTO tx_id FROM public.payment_transactions WHERE provider_transaction_id = p_provider_tx_id;
        RETURN jsonb_build_object('success', true, 'message', 'Payment transaction already processed', 'transaction_id', tx_id);
    END IF;

    IF (inv.amount_paid_minor + p_amount_minor) > inv.total_minor THEN
        DELETE FROM public.payment_transactions WHERE id = tx_id;
        RAISE EXCEPTION 'Settlement amount exceeds remaining invoice balance' USING ERRCODE = '22000';
    END IF;

    UPDATE public.payment_attempts SET status = 'succeeded', updated_at = NOW() WHERE id = att.id;

    new_paid := inv.amount_paid_minor + p_amount_minor;
    IF new_paid >= inv.total_minor THEN
        new_status := 'paid';
    ELSE
        new_status := 'partially_paid';
    END IF;

    UPDATE public.invoices
    SET amount_paid_minor = new_paid,
        status = new_status,
        paid_at = (CASE WHEN new_status = 'paid' THEN NOW() ELSE paid_at END),
        updated_at = NOW()
    WHERE id = inv.id;

    INSERT INTO public.receipts (
        transaction_id, invoice_id, student_id, amount_minor, currency
    )
    VALUES (
        tx_id, inv.id, inv.student_id, p_amount_minor, p_currency
    )
    RETURNING id INTO rec_id;

    IF new_status = 'paid' THEN
      PERFORM public.activate_paid_enrollment_for_invoice(inv.id, rec_id);
    ELSE
      UPDATE public.enrollments
      SET payment_status = 'partial',
          updated_at = NOW()
      WHERE id = inv.enrollment_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', tx_id,
        'receipt_id', rec_id,
        'invoice_id', inv.id,
        'amount_paid_minor', new_paid,
        'invoice_status', new_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_student_can_access_lesson(p_lesson_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    s_id UUID;
    sub_id UUID;
    has_access BOOLEAN;
BEGIN
    IF auth.uid() IS NULL OR public.is_admin_or_super() THEN
        RETURN true;
    END IF;

    SELECT id INTO s_id FROM public.students WHERE profile_id = auth.uid() AND status = 'active';
    IF s_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT COALESCE(u.subject_id, sem.subject_id) INTO sub_id
    FROM public.lessons l
    JOIN public.units u ON u.id = l.unit_id
    LEFT JOIN public.semesters sem ON sem.id = u.semester_id
    WHERE l.id = p_lesson_id;

    IF sub_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.enrollments e
        JOIN public.groups g ON g.id = e.group_id
        WHERE e.student_id = s_id
          AND public.enrollment_has_learning_access(e.id)
          AND g.subject_id = sub_id
          AND g.status = 'active'
    ) INTO has_access;

    RETURN has_access;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP FUNCTION IF EXISTS public.get_current_student_lessons();
CREATE OR REPLACE FUNCTION public.get_current_student_lessons()
RETURNS TABLE (
  lesson_id UUID,
  lesson_title TEXT,
  subject_name TEXT,
  unit_name TEXT,
  progress_percentage NUMERIC,
  estimated_minutes INT,
  last_page INT,
  total_pages INT,
  has_pdf BOOLEAN,
  has_code_playground BOOLEAN,
  pdf_bucket TEXT,
  pdf_object_path TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := public.current_student_id();
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student profile is not linked to this account' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (l.id)
    l.id AS lesson_id,
    COALESCE(l.title, 'Untitled lesson')::TEXT AS lesson_title,
    COALESCE(s.name, 'Assigned subject')::TEXT AS subject_name,
    COALESCE(u.name, 'Unit')::TEXT AS unit_name,
    COALESCE(lp.progress_percentage, 0)::NUMERIC AS progress_percentage,
    COALESCE(l.estimated_duration_minutes, 0)::INT AS estimated_minutes,
    GREATEST(1, COALESCE(CASE WHEN COALESCE(lp.last_position, '') ~ '^[0-9]+$' THEN lp.last_position::INT ELSE NULL END, 1))::INT AS last_page,
    GREATEST(1, COALESCE(NULLIF((lr.metadata->>'page_count'), '')::INT, 1))::INT AS total_pages,
    (lr.id IS NOT NULL)::BOOLEAN AS has_pdf,
    (l.lesson_type::TEXT = 'programming')::BOOLEAN AS has_code_playground,
    lr.bucket::TEXT AS pdf_bucket,
    lr.object_path::TEXT AS pdf_object_path
  FROM public.enrollments e
  JOIN public.groups g ON g.id = e.group_id
  JOIN public.units u ON u.subject_id = g.subject_id
  JOIN public.lessons l ON l.unit_id = u.id
  LEFT JOIN public.subjects s ON s.id = g.subject_id
  LEFT JOIN public.lesson_progress lp ON lp.lesson_id = l.id AND lp.student_id = v_student_id
  LEFT JOIN public.lesson_resources lr ON lr.lesson_id = l.id AND lr.resource_type = 'pdf'
  WHERE e.student_id = v_student_id
    AND public.enrollment_has_learning_access(e.id)
    AND g.status = 'active'
    AND u.status = 'active'
    AND l.status = 'published'
  ORDER BY l.id, u.order_number, l.order_number, lr.order_number;
END;
$$;

DROP FUNCTION IF EXISTS public.get_accessible_student_lessons(UUID);
CREATE OR REPLACE FUNCTION public.get_accessible_student_lessons(p_student_id UUID)
RETURNS TABLE (
  lesson_id UUID,
  lesson_title TEXT,
  subject_name TEXT,
  unit_name TEXT,
  progress_percentage NUMERIC,
  estimated_minutes INT,
  last_page INT,
  total_pages INT,
  has_pdf BOOLEAN,
  has_code_playground BOOLEAN,
  pdf_bucket TEXT,
  pdf_object_path TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_student_id IS NULL THEN
    RAISE EXCEPTION 'Student id is required' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    p_student_id = public.current_student_id()
    OR public.is_parent_of_student(auth.uid(), p_student_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view student lessons' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (l.id)
    l.id AS lesson_id,
    COALESCE(l.title, 'Untitled lesson')::TEXT AS lesson_title,
    COALESCE(s.name, 'Assigned subject')::TEXT AS subject_name,
    COALESCE(u.name, 'Unit')::TEXT AS unit_name,
    COALESCE(lp.progress_percentage, 0)::NUMERIC AS progress_percentage,
    COALESCE(l.estimated_duration_minutes, 0)::INT AS estimated_minutes,
    GREATEST(1, COALESCE(CASE WHEN COALESCE(lp.last_position, '') ~ '^[0-9]+$' THEN lp.last_position::INT ELSE NULL END, 1))::INT AS last_page,
    GREATEST(1, COALESCE(NULLIF((lr.metadata->>'page_count'), '')::INT, 1))::INT AS total_pages,
    (lr.id IS NOT NULL)::BOOLEAN AS has_pdf,
    (l.lesson_type::TEXT = 'programming')::BOOLEAN AS has_code_playground,
    lr.bucket::TEXT AS pdf_bucket,
    lr.object_path::TEXT AS pdf_object_path
  FROM public.enrollments e
  JOIN public.groups g ON g.id = e.group_id
  JOIN public.units u ON u.subject_id = g.subject_id
  JOIN public.lessons l ON l.unit_id = u.id
  LEFT JOIN public.subjects s ON s.id = g.subject_id
  LEFT JOIN public.lesson_progress lp ON lp.lesson_id = l.id AND lp.student_id = p_student_id
  LEFT JOIN public.lesson_resources lr ON lr.lesson_id = l.id AND lr.resource_type = 'pdf'
  WHERE e.student_id = p_student_id
    AND public.enrollment_has_learning_access(e.id)
    AND g.status = 'active'
    AND u.status = 'active'
    AND l.status = 'published'
  ORDER BY l.id, u.order_number, l.order_number, lr.order_number;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.enroll_student_in_group(UUID, UUID, BIGINT, BIGINT, TEXT, TIMESTAMPTZ) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, BIGINT, TEXT) FROM PUBLIC, authenticated;
REVOKE EXECUTE ON FUNCTION public.current_student_can_access_lesson(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_current_student_lessons() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_accessible_student_lessons(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enroll_student_in_group(UUID, UUID, BIGINT, BIGINT, TEXT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, BIGINT, TEXT) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.current_student_can_access_lesson(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_student_lessons() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_accessible_student_lessons(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
