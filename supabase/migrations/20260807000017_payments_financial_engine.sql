-- Migration: 20260807000017_payments_financial_engine.sql
-- Description: Phase 8 Subscriptions, Invoices, Payment Ledger & Financial Engine

-- 0. Invoice & Receipt Sequences
CREATE SEQUENCE IF NOT EXISTS public.invoice_number_seq START WITH 10001;
CREATE SEQUENCE IF NOT EXISTS public.receipt_number_seq START WITH 50001;

-- 1. Subscription Plans Table
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    billing_type TEXT NOT NULL CHECK (billing_type IN ('one_time', 'installment', 'recurring')),
    total_amount_minor BIGINT NOT NULL CHECK (total_amount_minor >= 0),
    currency TEXT NOT NULL DEFAULT 'EGP',
    installment_count INT NOT NULL DEFAULT 1 CHECK (installment_count >= 1),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Student Subscriptions Table (Snapshots Financial Terms)
CREATE TABLE IF NOT EXISTS public.student_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES public.subscription_plans(id) ON DELETE RESTRICT,
    agreed_total_minor BIGINT NOT NULL CHECK (agreed_total_minor >= 0),
    currency TEXT NOT NULL DEFAULT 'EGP',
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed', 'cancelled')),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Subscription Installments Table
CREATE TABLE IF NOT EXISTS public.subscription_installments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES public.student_subscriptions(id) ON DELETE CASCADE,
    sequence INT NOT NULL CHECK (sequence >= 1),
    due_date DATE NOT NULL,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_subscription_sequence UNIQUE (subscription_id, sequence)
);

-- 4. Invoices Table
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number TEXT UNIQUE NOT NULL DEFAULT ('INV-2026-' || LPAD(nextval('public.invoice_number_seq')::text, 6, '0')),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.student_subscriptions(id) ON DELETE SET NULL,
    currency TEXT NOT NULL DEFAULT 'EGP',
    subtotal_minor BIGINT NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
    discount_minor BIGINT NOT NULL DEFAULT 0 CHECK (discount_minor >= 0),
    total_minor BIGINT NOT NULL DEFAULT 0 CHECK (total_minor >= 0),
    amount_paid_minor BIGINT NOT NULL DEFAULT 0 CHECK (amount_paid_minor >= 0),
    status TEXT NOT NULL DEFAULT 'issued' CHECK (status IN ('draft', 'issued', 'partially_paid', 'paid', 'overdue', 'cancelled')),
    due_at TIMESTAMPTZ NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Invoice Line Items Table
CREATE TABLE IF NOT EXISTS public.invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity >= 1),
    unit_amount_minor BIGINT NOT NULL CHECK (unit_amount_minor >= 0),
    total_minor BIGINT NOT NULL CHECK (total_minor >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Payment Attempts Table
CREATE TABLE IF NOT EXISTS public.payment_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    provider TEXT NOT NULL CHECK (provider IN ('paymob', 'fawry', 'cash')),
    provider_reference TEXT,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    currency TEXT NOT NULL DEFAULT 'EGP',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('created', 'pending', 'succeeded', 'failed', 'cancelled', 'expired')),
    idempotency_key TEXT UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '1 hour'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Immutable Payment Transactions Ledger Table
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    payment_attempt_id UUID REFERENCES public.payment_attempts(id) ON DELETE SET NULL,
    provider TEXT NOT NULL CHECK (provider IN ('paymob', 'fawry', 'cash')),
    provider_transaction_id TEXT UNIQUE NOT NULL,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    currency TEXT NOT NULL DEFAULT 'EGP',
    transaction_type TEXT NOT NULL DEFAULT 'payment' CHECK (transaction_type IN ('payment', 'refund', 'adjustment')),
    status TEXT NOT NULL DEFAULT 'succeeded' CHECK (status IN ('succeeded', 'reversed', 'failed')),
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Receipts Table
CREATE TABLE IF NOT EXISTS public.receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_number TEXT UNIQUE NOT NULL DEFAULT ('REC-2026-' || LPAD(nextval('public.receipt_number_seq')::text, 6, '0')),
    transaction_id UUID NOT NULL REFERENCES public.payment_transactions(id) ON DELETE RESTRICT,
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    currency TEXT NOT NULL DEFAULT 'EGP',
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Enable RLS on all Phase 8 tables
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;

-- 10. RLS Policies
CREATE POLICY "Subscription plans viewable by authenticated users"
ON public.subscription_plans FOR SELECT TO authenticated USING (true);

CREATE POLICY "Student subscriptions viewable by owner, parent, or staff"
ON public.student_subscriptions FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('subscriptions.view') OR
    EXISTS (SELECT 1 FROM public.students s WHERE s.id = student_subscriptions.student_id AND s.profile_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.students s WHERE s.id = student_subscriptions.student_id AND public.current_parent_has_student(s.id))
);

CREATE POLICY "Invoices viewable by owner, parent, or authorized staff"
ON public.invoices FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('invoices.view') OR
    EXISTS (SELECT 1 FROM public.students s WHERE s.id = invoices.student_id AND s.profile_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.students s WHERE s.id = invoices.student_id AND public.current_parent_has_student(s.id))
);

CREATE POLICY "Invoice items viewable by authorized invoice readers"
ON public.invoice_items FOR SELECT TO authenticated
USING (
    EXISTS (SELECT 1 FROM public.invoices inv WHERE inv.id = invoice_items.invoice_id AND (
        public.is_admin_or_super() OR
        public.has_permission('invoices.view') OR
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = inv.student_id AND s.profile_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = inv.student_id AND public.current_parent_has_student(s.id))
    ))
);

CREATE POLICY "Payment attempts viewable by owner or authorized staff"
ON public.payment_attempts FOR SELECT TO authenticated
USING (
    EXISTS (SELECT 1 FROM public.invoices inv WHERE inv.id = payment_attempts.invoice_id AND (
        public.is_admin_or_super() OR
        public.has_permission('payments.view') OR
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = inv.student_id AND s.profile_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = inv.student_id AND public.current_parent_has_student(s.id))
    ))
);

CREATE POLICY "Payment transactions viewable by owner or authorized staff"
ON public.payment_transactions FOR SELECT TO authenticated
USING (
    EXISTS (SELECT 1 FROM public.invoices inv WHERE inv.id = payment_transactions.invoice_id AND (
        public.is_admin_or_super() OR
        public.has_permission('payments.view') OR
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = inv.student_id AND s.profile_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = inv.student_id AND public.current_parent_has_student(s.id))
    ))
);

CREATE POLICY "Receipts viewable by owner or authorized staff"
ON public.receipts FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('payments.view') OR
    EXISTS (SELECT 1 FROM public.students s WHERE s.id = receipts.student_id AND s.profile_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.students s WHERE s.id = receipts.student_id AND public.current_parent_has_student(s.id))
);

-- 11. Server-Authoritative Financial RPCs

-- Create Payment Intent RPC (Calculates Authoritative Balance Server-Side)
CREATE OR REPLACE FUNCTION public.create_payment_intent(
    p_invoice_id UUID,
    p_provider TEXT,
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    inv RECORD;
    remaining_balance BIGINT;
    attempt_id UUID;
BEGIN
    SELECT * INTO inv FROM public.invoices WHERE id = p_invoice_id FOR UPDATE;
    IF inv.id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found' USING ERRCODE = '44000';
    END IF;

    -- Verify authorization (owner student, linked parent, or finance staff)
    IF NOT (
        public.is_admin_or_super() OR
        public.has_permission('payments.collect') OR
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = inv.student_id AND s.profile_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = inv.student_id AND public.current_parent_has_student(s.id))
    ) THEN
        RAISE EXCEPTION 'Unauthorized to create payment intent for this invoice' USING ERRCODE = '42501';
    END IF;

    IF inv.status IN ('paid', 'cancelled') THEN
        RAISE EXCEPTION 'Cannot create payment intent for settled or cancelled invoice' USING ERRCODE = '22000';
    END IF;

    remaining_balance := inv.total_minor - inv.amount_paid_minor;
    IF remaining_balance <= 0 THEN
        RAISE EXCEPTION 'Invoice balance is zero' USING ERRCODE = '22000';
    END IF;

    -- Insert or return idempotent payment attempt
    INSERT INTO public.payment_attempts (
        invoice_id, provider, amount_minor, currency, status, idempotency_key, expires_at
    )
    VALUES (
        p_invoice_id, p_provider, remaining_balance, inv.currency, 'pending', p_idempotency_key, NOW() + INTERVAL '1 hour'
    )
    ON CONFLICT (idempotency_key) DO UPDATE SET updated_at = NOW()
    RETURNING id INTO attempt_id;

    RETURN jsonb_build_object(
        'success', true,
        'attempt_id', attempt_id,
        'invoice_id', inv.id,
        'invoice_number', inv.invoice_number,
        'amount_minor', remaining_balance,
        'currency', inv.currency,
        'provider', p_provider
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Apply Verified Payment RPC (Authoritative Settlement & Receipt Generation)
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

    -- Record Immutable Payment Transaction (Idempotent by provider_transaction_id)
    INSERT INTO public.payment_transactions (
        invoice_id, payment_attempt_id, provider, provider_transaction_id, amount_minor, currency, status
    )
    VALUES (
        inv.id, att.id, att.provider, p_provider_tx_id, p_amount_minor, p_currency, 'succeeded'
    )
    ON CONFLICT (provider_transaction_id) DO NOTHING
    RETURNING id INTO tx_id;

    -- If transaction was already processed, return idempotent response
    IF tx_id IS NULL THEN
        SELECT id INTO tx_id FROM public.payment_transactions WHERE provider_transaction_id = p_provider_tx_id;
        RETURN jsonb_build_object('success', true, 'message', 'Payment transaction already processed', 'transaction_id', tx_id);
    END IF;

    -- Update Payment Attempt status
    UPDATE public.payment_attempts SET status = 'succeeded', updated_at = NOW() WHERE id = att.id;

    -- Recalculate Invoice Settlement
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

    -- Auto-Generate Receipt
    INSERT INTO public.receipts (
        transaction_id, invoice_id, student_id, amount_minor, currency
    )
    VALUES (
        tx_id, inv.id, inv.student_id, p_amount_minor, p_currency
    )
    RETURNING id INTO rec_id;

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

-- Record Manual / Cash Payment RPC (Authoritative Staff Cashier Collection)
CREATE OR REPLACE FUNCTION public.record_manual_payment(
    p_invoice_id UUID,
    p_amount_minor BIGINT,
    p_payment_method TEXT DEFAULT 'cash',
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    inv RECORD;
    idemp_key TEXT;
    att_res JSONB;
    att_id UUID;
    tx_ref TEXT;
BEGIN
    IF NOT (public.is_admin_or_super() OR public.has_permission('payments.collect')) THEN
        RAISE EXCEPTION 'Unauthorized to record manual cash payment' USING ERRCODE = '42501';
    END IF;

    IF p_amount_minor <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO inv FROM public.invoices WHERE id = p_invoice_id FOR UPDATE;
    IF inv.id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found' USING ERRCODE = '44000';
    END IF;

    IF (inv.amount_paid_minor + p_amount_minor) > inv.total_minor THEN
        RAISE EXCEPTION 'Manual payment exceeds remaining invoice balance' USING ERRCODE = '22000';
    END IF;

    idemp_key := 'CASH-MANUAL-' || p_invoice_id || '-' || NOW();
    tx_ref := 'TX-CASH-' || gen_random_uuid();

    INSERT INTO public.payment_attempts (
        invoice_id, provider, amount_minor, currency, status, idempotency_key
    )
    VALUES (
        p_invoice_id, 'cash', p_amount_minor, inv.currency, 'succeeded', idemp_key
    )
    RETURNING id INTO att_id;

    RETURN public.apply_verified_payment(att_id, tx_ref, p_amount_minor, inv.currency);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Student Financial Summary RPC
CREATE OR REPLACE FUNCTION public.get_student_financial_summary(p_student_id UUID)
RETURNS JSONB AS $$
DECLARE
    tot_due BIGINT := 0;
    tot_paid BIGINT := 0;
    tot_rem BIGINT := 0;
    inv_count INT := 0;
BEGIN
    SELECT
        COUNT(*)::int,
        COALESCE(SUM(total_minor), 0)::bigint,
        COALESCE(SUM(amount_paid_minor), 0)::bigint
    INTO inv_count, tot_due, tot_paid
    FROM public.invoices
    WHERE student_id = p_student_id AND status != 'cancelled';

    tot_rem := tot_due - tot_paid;
    IF tot_rem < 0 THEN tot_rem := 0; END IF;

    RETURN jsonb_build_object(
        'student_id', p_student_id,
        'invoice_count', inv_count,
        'total_due_minor', tot_due,
        'total_paid_minor', tot_paid,
        'remaining_balance_minor', tot_rem,
        'currency', 'EGP'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.create_payment_intent(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_payment_intent(UUID, TEXT, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, BIGINT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, BIGINT, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.record_manual_payment(UUID, BIGINT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_manual_payment(UUID, BIGINT, TEXT, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_student_financial_summary(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_student_financial_summary(UUID) TO authenticated;
