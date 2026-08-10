-- UNIFIED FIX SCRIPT
-- Please run this ENTIRE script in your Supabase SQL Editor

-- 1. Fix is_teacher_of_group helper
CREATE OR REPLACE FUNCTION public.is_teacher_of_group(teacher_user_id UUID, target_group_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    t_id UUID;
    is_assigned BOOLEAN := false;
BEGIN
    t_id := public.get_teacher_id(teacher_user_id);
    IF t_id IS NULL THEN RETURN false; END IF;
    SELECT EXISTS (
        SELECT 1 FROM public.group_teachers
        WHERE group_id = target_group_id 
          AND teacher_id = t_id
          AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
    ) INTO is_assigned;
    RETURN is_assigned;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. Drop the old Groups and Schedules RLS policies
DROP POLICY IF EXISTS "Groups viewable by enrolled students, assigned teachers, staff, admins" ON public.groups;
DROP POLICY IF EXISTS "Schedules viewable by group participants, staff, admins" ON public.schedules;

-- 3. Recreate the Schedules RLS Policy
CREATE POLICY "Schedules viewable by group participants, staff, admins" ON public.schedules FOR SELECT TO authenticated USING (
    public.is_student_enrolled_in_group(auth.uid(), group_id)
    OR public.is_teacher_of_group(auth.uid(), group_id)
    OR public.current_user_role() IN ('admin', 'staff', 'super_admin')
);

-- 4. Recreate the Finance Overview Function
DROP FUNCTION IF EXISTS public.get_teacher_financial_overview(uuid);

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

-- 5. Recreate Roster Function
DROP FUNCTION IF EXISTS public.get_teacher_group_finance_roster(uuid);

CREATE OR REPLACE FUNCTION public.get_teacher_group_finance_roster(p_group_id UUID)
RETURNS TABLE (
  student_id UUID,
  student_name TEXT,
  parent_phone TEXT,
  enrollment_id UUID,
  payment_status TEXT,
  payment_exempt BOOLEAN,
  final_price_minor BIGINT,
  paid_minor BIGINT,
  remaining_minor BIGINT,
  currency TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.has_permission('payments.view') AND NOT EXISTS (
      SELECT 1 FROM public.group_teachers gt
      WHERE gt.group_id = p_group_id
        AND gt.teacher_id = public.current_teacher_id()
    ) THEN
      RAISE EXCEPTION 'Unauthorized to view group roster' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT 
      st.id AS student_id,
      pr.full_name AS student_name,
      par_pr.phone_number AS parent_phone,
      e.id AS enrollment_id,
      e.payment_status,
      e.payment_exempt,
      COALESCE(e.final_price_minor, inv.total_minor, 0)::BIGINT AS final_price_minor,
      COALESCE(inv.amount_paid_minor, 0)::BIGINT AS paid_minor,
      GREATEST(COALESCE(e.final_price_minor, inv.total_minor, 0) - COALESCE(inv.amount_paid_minor, 0), 0)::BIGINT AS remaining_minor,
      COALESCE(e.currency, inv.currency, 'EGP') AS currency
    FROM public.enrollments e
    JOIN public.students st ON st.id = e.student_id
    JOIN public.profiles pr ON pr.id = st.profile_id
    LEFT JOIN public.parent_students ps ON ps.student_id = st.id
    LEFT JOIN public.parents par ON par.id = ps.parent_id
    LEFT JOIN public.profiles par_pr ON par_pr.id = par.profile_id
    LEFT JOIN public.invoices inv ON inv.id = e.activation_invoice_id
    WHERE e.group_id = p_group_id
      AND e.status = 'active'
    ORDER BY pr.full_name;
END;
$$;