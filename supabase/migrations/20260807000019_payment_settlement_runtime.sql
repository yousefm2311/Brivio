-- Migration: 20260807000019_payment_settlement_runtime.sql
-- Description: Phase 8.95 Payment Settlement Runtime Security, Service Role Grants & Manual Payment Idempotency

-- 1. Schema Grants for Service Role, Authenticated, Anon & Postgres
--    Grant service_role and postgres full access
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role, postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role, postgres;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role, postgres;

--    Grant table SELECT access to authenticated & anon for RLS policies and helper functions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated, anon;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;

--    Preserve assessment security contract: question_options direct SELECT remains strictly revoked
REVOKE SELECT ON public.question_options FROM authenticated, anon;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role, postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role, postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role, postgres;

-- 2. Restrict apply_verified_payment to trusted service_role only (RPC security hardening)
--    Idempotent provider_transaction_id check runs BEFORE overcollection validation
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

    -- Record Immutable Payment Transaction (Idempotent by provider_transaction_id) FIRST
    INSERT INTO public.payment_transactions (
        invoice_id, payment_attempt_id, provider, provider_transaction_id, amount_minor, currency, status
    )
    VALUES (
        inv.id, att.id, att.provider, p_provider_tx_id, p_amount_minor, p_currency, 'succeeded'
    )
    ON CONFLICT (provider_transaction_id) DO NOTHING
    RETURNING id INTO tx_id;

    -- If transaction was already processed, return idempotent success response immediately
    IF tx_id IS NULL THEN
        SELECT id INTO tx_id FROM public.payment_transactions WHERE provider_transaction_id = p_provider_tx_id;
        RETURN jsonb_build_object('success', true, 'message', 'Payment transaction already processed', 'transaction_id', tx_id);
    END IF;

    -- Overcollection guard (for new transactions)
    IF (inv.amount_paid_minor + p_amount_minor) > inv.total_minor THEN
        -- Rollback inserted transaction on overcollection
        DELETE FROM public.payment_transactions WHERE id = tx_id;
        RAISE EXCEPTION 'Settlement amount exceeds remaining invoice balance' USING ERRCODE = '22000';
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

REVOKE EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, BIGINT, TEXT) FROM PUBLIC, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, BIGINT, TEXT) TO service_role, postgres;

-- 3. Idempotency Conflict Enforcement in create_payment_intent
CREATE OR REPLACE FUNCTION public.create_payment_intent(
    p_invoice_id UUID,
    p_provider TEXT,
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    inv RECORD;
    existing_att RECORD;
    remaining_balance BIGINT;
    attempt_id UUID;
BEGIN
    -- Check existing idempotency key conflict with different invoice or provider first
    SELECT * INTO existing_att FROM public.payment_attempts WHERE idempotency_key = p_idempotency_key;
    IF existing_att.id IS NOT NULL THEN
        IF existing_att.invoice_id != p_invoice_id OR existing_att.provider != p_provider THEN
            RAISE EXCEPTION 'Idempotency key conflict: key already used for a different invoice or provider' USING ERRCODE = '23505';
        END IF;
    END IF;

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

-- 4. Drop legacy 4-parameter record_manual_payment to prevent PostgREST 300 ambiguity
DROP FUNCTION IF EXISTS public.record_manual_payment(UUID, BIGINT, TEXT, TEXT);

-- 5. Single canonical 5-parameter record_manual_payment function
CREATE OR REPLACE FUNCTION public.record_manual_payment(
    p_invoice_id UUID,
    p_amount_minor BIGINT,
    p_payment_method TEXT DEFAULT 'cash',
    p_notes TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    inv RECORD;
    existing_att RECORD;
    idemp_key TEXT;
    att_id UUID;
    tx_ref TEXT;
BEGIN
    IF NOT (public.is_admin_or_super() OR public.has_permission('payments.collect')) THEN
        RAISE EXCEPTION 'Unauthorized to record manual cash payment' USING ERRCODE = '42501';
    END IF;

    IF p_amount_minor <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero' USING ERRCODE = '22023';
    END IF;

    idemp_key := COALESCE(p_idempotency_key, 'CASH-MANUAL-' || p_invoice_id || '-' || NOW());
    tx_ref := 'TX-CASH-' || idemp_key;

    -- Check if idempotency key was already processed
    SELECT id INTO att_id FROM public.payment_attempts WHERE idempotency_key = idemp_key AND status = 'succeeded';
    IF att_id IS NOT NULL THEN
        SELECT currency INTO inv FROM public.invoices WHERE id = p_invoice_id;
        RETURN public.apply_verified_payment(att_id, tx_ref, p_amount_minor, inv.currency);
    END IF;

    SELECT * INTO inv FROM public.invoices WHERE id = p_invoice_id FOR UPDATE;
    IF inv.id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found' USING ERRCODE = '44000';
    END IF;

    IF (inv.amount_paid_minor + p_amount_minor) > inv.total_minor THEN
        RAISE EXCEPTION 'Manual payment exceeds remaining invoice balance' USING ERRCODE = '22000';
    END IF;

    INSERT INTO public.payment_attempts (
        invoice_id, provider, amount_minor, currency, status, idempotency_key
    )
    VALUES (
        p_invoice_id, 'cash', p_amount_minor, inv.currency, 'succeeded', idemp_key
    )
    ON CONFLICT (idempotency_key) DO UPDATE SET updated_at = NOW()
    RETURNING id INTO att_id;

    RETURN public.apply_verified_payment(att_id, tx_ref, p_amount_minor, inv.currency);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.record_manual_payment(UUID, BIGINT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_manual_payment(UUID, BIGINT, TEXT, TEXT, TEXT) TO authenticated, service_role;
