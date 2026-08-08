-- Migration: 20260807000018_payment_provider_security.sql
-- Description: Phase 8.5 Payment Provider Audit Table & Hardened Settlement RPC Permissions

-- 1. Create Payment Provider Audit Events Table
CREATE TABLE IF NOT EXISTS public.payment_provider_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT NOT NULL CHECK (provider IN ('paymob', 'fawry', 'cash')),
    provider_event_id TEXT,
    transaction_reference TEXT,
    event_type TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'received' CHECK (status IN ('received', 'processed', 'rejected', 'quarantined')),
    error_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Enable RLS on payment_provider_events
ALTER TABLE public.payment_provider_events ENABLE ROW LEVEL SECURITY;

-- 3. Lock down apply_verified_payment: REVOKE from PUBLIC and authenticated; GRANT strictly to service_role!
REVOKE EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, BIGINT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, BIGINT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, BIGINT, TEXT) TO service_role;

-- 4. Audit Table RLS Policies - Only Admin/Staff can view payment provider events
CREATE POLICY "Payment provider events viewable by finance staff and admin"
ON public.payment_provider_events FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('payments.view')
);

-- 5. Ensure Unique Constraint on (provider, provider_transaction_id) in payment_transactions
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'unique_provider_transaction'
    ) THEN
        ALTER TABLE public.payment_transactions
        ADD CONSTRAINT unique_provider_transaction UNIQUE (provider, provider_transaction_id);
    END IF;
END $$;
