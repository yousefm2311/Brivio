-- Migration: 20260809001400_teacher_finance_and_qr_consume.sql
-- Description: One-time QR login consumption, teacher financial visibility, and discount/exemption requests.

ALTER TABLE public.account_login_qr_tokens
  ADD COLUMN IF NOT EXISTS consumed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS consumed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.consume_account_login_qr(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_hash TEXT;
  v_profile_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required to consume QR token' USING ERRCODE = '42501';
  END IF;

  IF p_token IS NULL OR LENGTH(TRIM(p_token)) < 20 THEN
    RAISE EXCEPTION 'Invalid QR token' USING ERRCODE = '22000';
  END IF;

  v_hash := encode(digest(TRIM(p_token), 'sha256'), 'hex');

  SELECT profile_id
  INTO v_profile_id
  FROM public.account_login_qr_tokens
  WHERE token_hash = v_hash
    AND status = 'active'
    AND expires_at > NOW()
  FOR UPDATE;

  IF v_profile_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'QR token is expired or already used.');
  END IF;

  IF v_profile_id <> auth.uid() THEN
    RAISE EXCEPTION 'QR token does not belong to the authenticated account' USING ERRCODE = '42501';
  END IF;

  UPDATE public.account_login_qr_tokens
  SET status = 'revoked',
      consumed_at = NOW(),
      consumed_by = auth.uid(),
      updated_at = NOW()
  WHERE token_hash = v_hash;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE TABLE IF NOT EXISTS public.payment_adjustment_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
  requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  adjustment_type TEXT NOT NULL CHECK (adjustment_type IN ('discount', 'exemption')),
  original_price_minor BIGINT NOT NULL DEFAULT 0 CHECK (original_price_minor >= 0),
  requested_discount_minor BIGINT NOT NULL DEFAULT 0 CHECK (requested_discount_minor >= 0),
  requested_final_price_minor BIGINT NOT NULL DEFAULT 0 CHECK (requested_final_price_minor >= 0),
  currency TEXT NOT NULL DEFAULT 'EGP',
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'applied', 'cancelled')),
  decision_note TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  decided_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_adjustment_requests_group_status
ON public.payment_adjustment_requests(group_id, status, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_payment_adjustment_requests_student_status
ON public.payment_adjustment_requests(student_id, status, requested_at DESC);

ALTER TABLE public.payment_adjustment_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Payment adjustment requests readable by finance roles" ON public.payment_adjustment_requests;
CREATE POLICY "Payment adjustment requests readable by finance roles"
ON public.payment_adjustment_requests FOR SELECT TO authenticated USING (
  public.is_admin_or_super()
  OR public.has_permission('payments.view')
  OR public.has_permission('payments.collect')
  OR EXISTS (
    SELECT 1
    FROM public.group_teachers gt
    WHERE gt.group_id = payment_adjustment_requests.group_id
      AND gt.teacher_id = public.current_teacher_id()
      AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
  )
);

CREATE OR REPLACE FUNCTION public.get_teacher_financial_overview(p_teacher_id UUID DEFAULT NULL)
RETURNS TABLE (
  group_id UUID,
  group_name TEXT,
  group_code TEXT,
  subject_name TEXT,
  total_students BIGINT,
  paid_students BIGINT,
  unpaid_students BIGINT,
  exempt_students BIGINT,
  total_amount_minor BIGINT,
  paid_amount_minor BIGINT,
  remaining_amount_minor BIGINT,
  currency TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID := COALESCE(p_teacher_id, public.current_teacher_id());
BEGIN
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Teacher profile is required' USING ERRCODE = '42501';
  END IF;

  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('payments.view')
    OR public.has_permission('payments.collect')
    OR v_teacher_id = public.current_teacher_id()
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view teacher finance' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH assigned_groups AS (
    SELECT DISTINCT g.id, g.name, g.code, g.subject_id
    FROM public.group_teachers gt
    JOIN public.groups g ON g.id = gt.group_id
    WHERE gt.teacher_id = v_teacher_id
      AND (gt.effective_to IS NULL OR gt.effective_to >= CURRENT_DATE)
  ),
  finance_rows AS (
    SELECT
      ag.id AS group_id,
      ag.name AS group_name,
      ag.code AS group_code,
      s.name AS subject_name,
      e.id AS enrollment_id,
      COALESCE(e.currency, inv.currency, 'EGP') AS currency,
      COALESCE(e.final_price_minor, inv.total_minor, 0) AS final_price_minor,
      COALESCE(inv.amount_paid_minor, 0) AS paid_minor,
      e.payment_status,
      e.payment_exempt
    FROM assigned_groups ag
    LEFT JOIN public.subjects s ON s.id = ag.subject_id
    LEFT JOIN public.enrollments e ON e.group_id = ag.id AND e.status = 'active'
    LEFT JOIN public.invoices inv ON inv.id = e.activation_invoice_id
  )
  SELECT
    fr.group_id,
    fr.group_name,
    fr.group_code,
    fr.subject_name,
    COUNT(fr.enrollment_id)::BIGINT AS total_students,
    COUNT(fr.enrollment_id) FILTER (
      WHERE fr.payment_status IN ('paid', 'exempt') OR fr.payment_exempt = true
    )::BIGINT AS paid_students,
    COUNT(fr.enrollment_id) FILTER (
      WHERE COALESCE(fr.final_price_minor, 0) > COALESCE(fr.paid_minor, 0)
        AND COALESCE(fr.payment_exempt, false) = false
    )::BIGINT AS unpaid_students,
    COUNT(fr.enrollment_id) FILTER (
      WHERE fr.payment_status = 'exempt' OR fr.payment_exempt = true
    )::BIGINT AS exempt_students,
    COALESCE(SUM(fr.final_price_minor), 0)::BIGINT AS total_amount_minor,
    COALESCE(SUM(fr.paid_minor), 0)::BIGINT AS paid_amount_minor,
    COALESCE(SUM(GREATEST(fr.final_price_minor - fr.paid_minor, 0)), 0)::BIGINT AS remaining_amount_minor,
    COALESCE(MAX(fr.currency), 'EGP') AS currency
  FROM finance_rows fr
  GROUP BY fr.group_id, fr.group_name, fr.group_code, fr.subject_name
  ORDER BY fr.group_name;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_teacher_group_finance_roster(p_group_id UUID)
RETURNS TABLE (
  enrollment_id UUID,
  student_id UUID,
  student_name TEXT,
  student_code TEXT,
  invoice_id UUID,
  invoice_number TEXT,
  original_price_minor BIGINT,
  discount_minor BIGINT,
  final_price_minor BIGINT,
  paid_amount_minor BIGINT,
  remaining_amount_minor BIGINT,
  currency TEXT,
  access_status TEXT,
  payment_status TEXT,
  payment_exempt BOOLEAN,
  pending_adjustment_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.is_admin_or_super()
    OR public.has_permission('payments.view')
    OR public.has_permission('payments.collect')
    OR public.current_teacher_assigned_to_group(p_group_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized to view group finance roster' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    e.id AS enrollment_id,
    st.id AS student_id,
    p.full_name AS student_name,
    st.student_code,
    inv.id AS invoice_id,
    inv.invoice_number,
    COALESCE(e.original_price_minor, inv.subtotal_minor, 0)::BIGINT AS original_price_minor,
    COALESCE(e.discount_minor, inv.discount_minor, 0)::BIGINT AS discount_minor,
    COALESCE(e.final_price_minor, inv.total_minor, 0)::BIGINT AS final_price_minor,
    COALESCE(inv.amount_paid_minor, 0)::BIGINT AS paid_amount_minor,
    GREATEST(COALESCE(e.final_price_minor, inv.total_minor, 0) - COALESCE(inv.amount_paid_minor, 0), 0)::BIGINT AS remaining_amount_minor,
    COALESCE(e.currency, inv.currency, 'EGP') AS currency,
    COALESCE(e.access_status, 'active') AS access_status,
    COALESCE(e.payment_status, 'paid') AS payment_status,
    COALESCE(e.payment_exempt, false) AS payment_exempt,
    COALESCE((
      SELECT COUNT(*)
      FROM public.payment_adjustment_requests par
      WHERE par.enrollment_id = e.id
        AND par.status = 'pending'
    ), 0)::BIGINT AS pending_adjustment_count
  FROM public.enrollments e
  JOIN public.students st ON st.id = e.student_id
  JOIN public.profiles p ON p.id = st.profile_id
  LEFT JOIN public.invoices inv ON inv.id = e.activation_invoice_id
  WHERE e.group_id = p_group_id
    AND e.status = 'active'
  ORDER BY p.full_name;
END;
$$;

CREATE OR REPLACE FUNCTION public.request_teacher_payment_adjustment(
  p_enrollment_id UUID,
  p_discount_minor BIGINT,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  e_rec public.enrollments%ROWTYPE;
  v_teacher_id UUID;
  v_original BIGINT;
  v_discount BIGINT;
  v_final BIGINT;
  v_type TEXT;
  v_request_id UUID;
BEGIN
  v_teacher_id := public.current_teacher_id();
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Teacher profile is required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO e_rec
  FROM public.enrollments
  WHERE id = p_enrollment_id
  FOR UPDATE;

  IF e_rec.id IS NULL THEN
    RAISE EXCEPTION 'Enrollment not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.current_teacher_assigned_to_group(e_rec.group_id) THEN
    RAISE EXCEPTION 'Unauthorized to request adjustment for this group' USING ERRCODE = '42501';
  END IF;

  v_original := COALESCE(e_rec.original_price_minor, e_rec.final_price_minor, 0);
  v_discount := GREATEST(COALESCE(p_discount_minor, 0), 0);
  IF v_discount > v_original THEN
    v_discount := v_original;
  END IF;
  v_final := GREATEST(v_original - v_discount, 0);
  v_type := CASE WHEN v_final = 0 THEN 'exemption' ELSE 'discount' END;

  IF EXISTS (
    SELECT 1 FROM public.payment_adjustment_requests
    WHERE enrollment_id = e_rec.id
      AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'There is already a pending adjustment request for this enrollment' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.payment_adjustment_requests (
    enrollment_id,
    student_id,
    group_id,
    teacher_id,
    requested_by,
    adjustment_type,
    original_price_minor,
    requested_discount_minor,
    requested_final_price_minor,
    currency,
    reason,
    status
  )
  VALUES (
    e_rec.id,
    e_rec.student_id,
    e_rec.group_id,
    v_teacher_id,
    auth.uid(),
    v_type,
    v_original,
    v_discount,
    v_final,
    COALESCE(e_rec.currency, 'EGP'),
    NULLIF(TRIM(COALESCE(p_reason, '')), ''),
    'pending'
  )
  RETURNING id INTO v_request_id;

  IF public.has_permission('payments.collect') THEN
    PERFORM public.apply_payment_adjustment_request(
      v_request_id,
      true,
      'Applied directly by authorized teacher.'
    );

    RETURN jsonb_build_object(
      'success', true,
      'request_id', v_request_id,
      'adjustment_type', v_type,
      'final_price_minor', v_final,
      'status', 'applied',
      'message', 'Adjustment applied by authorized teacher.'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_request_id,
    'adjustment_type', v_type,
    'final_price_minor', v_final,
    'status', 'pending',
    'message', 'Adjustment request sent to finance/admin for approval.'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_payment_adjustment_request(
  p_request_id UUID,
  p_approve BOOLEAN,
  p_decision_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  req public.payment_adjustment_requests%ROWTYPE;
  inv_id UUID;
BEGIN
  IF NOT (public.is_admin_or_super() OR public.has_permission('payments.collect')) THEN
    RAISE EXCEPTION 'Unauthorized to decide payment adjustment requests' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO req
  FROM public.payment_adjustment_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF req.id IS NULL THEN
    RAISE EXCEPTION 'Adjustment request not found' USING ERRCODE = 'P0002';
  END IF;

  IF req.status <> 'pending' THEN
    RAISE EXCEPTION 'Adjustment request is not pending' USING ERRCODE = '22000';
  END IF;

  IF NOT p_approve THEN
    UPDATE public.payment_adjustment_requests
    SET status = 'rejected',
        approved_by = auth.uid(),
        decision_note = p_decision_note,
        decided_at = NOW(),
        updated_at = NOW()
    WHERE id = req.id;
    RETURN jsonb_build_object('success', true, 'status', 'rejected');
  END IF;

  SELECT activation_invoice_id INTO inv_id
  FROM public.enrollments
  WHERE id = req.enrollment_id
  FOR UPDATE;

  UPDATE public.enrollments
  SET discount_minor = req.requested_discount_minor,
      final_price_minor = req.requested_final_price_minor,
      payment_exempt = req.requested_final_price_minor = 0,
      payment_status = CASE WHEN req.requested_final_price_minor = 0 THEN 'exempt' ELSE payment_status END,
      access_status = CASE WHEN req.requested_final_price_minor = 0 THEN 'active' ELSE access_status END,
      payment_exemption_reason = CASE WHEN req.requested_final_price_minor = 0 THEN req.reason ELSE payment_exemption_reason END,
      updated_at = NOW()
  WHERE id = req.enrollment_id;

  IF inv_id IS NOT NULL THEN
    UPDATE public.invoices
    SET discount_minor = req.requested_discount_minor,
        total_minor = req.requested_final_price_minor,
        status = CASE
          WHEN req.requested_final_price_minor = 0 THEN 'paid'
          WHEN amount_paid_minor >= req.requested_final_price_minor THEN 'paid'
          WHEN amount_paid_minor > 0 THEN 'partially_paid'
          ELSE status
        END,
        paid_at = CASE
          WHEN req.requested_final_price_minor = 0 THEN NOW()
          WHEN amount_paid_minor >= req.requested_final_price_minor THEN COALESCE(paid_at, NOW())
          ELSE paid_at
        END,
        updated_at = NOW()
    WHERE id = inv_id;
  END IF;

  UPDATE public.payment_adjustment_requests
  SET status = 'applied',
      approved_by = auth.uid(),
      decision_note = p_decision_note,
      decided_at = NOW(),
      updated_at = NOW()
  WHERE id = req.id;

  RETURN jsonb_build_object('success', true, 'status', 'applied');
END;
$$;

CREATE OR REPLACE FUNCTION public.get_payment_adjustment_requests(p_status TEXT DEFAULT NULL)
RETURNS TABLE (
  request_id UUID,
  enrollment_id UUID,
  student_name TEXT,
  student_code TEXT,
  group_name TEXT,
  group_code TEXT,
  teacher_name TEXT,
  adjustment_type TEXT,
  original_price_minor BIGINT,
  requested_discount_minor BIGINT,
  requested_final_price_minor BIGINT,
  currency TEXT,
  reason TEXT,
  status TEXT,
  requested_at TIMESTAMPTZ,
  decision_note TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (public.is_admin_or_super() OR public.has_permission('payments.view') OR public.has_permission('payments.collect')) THEN
    RAISE EXCEPTION 'Unauthorized to view payment adjustment requests' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    par.id AS request_id,
    par.enrollment_id,
    sp.full_name AS student_name,
    st.student_code,
    g.name AS group_name,
    g.code AS group_code,
    tp.full_name AS teacher_name,
    par.adjustment_type,
    par.original_price_minor,
    par.requested_discount_minor,
    par.requested_final_price_minor,
    par.currency,
    par.reason,
    par.status,
    par.requested_at,
    par.decision_note
  FROM public.payment_adjustment_requests par
  JOIN public.students st ON st.id = par.student_id
  JOIN public.profiles sp ON sp.id = st.profile_id
  JOIN public.groups g ON g.id = par.group_id
  LEFT JOIN public.teachers t ON t.id = par.teacher_id
  LEFT JOIN public.profiles tp ON tp.id = t.profile_id
  WHERE p_status IS NULL OR par.status = p_status
  ORDER BY par.requested_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.consume_account_login_qr(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_teacher_financial_overview(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_teacher_group_finance_roster(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.request_teacher_payment_adjustment(UUID, BIGINT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.apply_payment_adjustment_request(UUID, BOOLEAN, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_payment_adjustment_requests(TEXT) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.consume_account_login_qr(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_teacher_financial_overview(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_teacher_group_finance_roster(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_teacher_payment_adjustment(UUID, BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_payment_adjustment_request(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_payment_adjustment_requests(TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
