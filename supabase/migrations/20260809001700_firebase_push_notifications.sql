-- Migration: 20260809001700_firebase_push_notifications.sql
-- Description: Firebase Cloud Messaging device tokens and push delivery queue.

CREATE TABLE IF NOT EXISTS public.device_push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL DEFAULT 'unknown',
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_push_tokens_user_active
ON public.device_push_tokens(user_id, is_active, last_seen_at DESC);

CREATE TABLE IF NOT EXISTS public.notification_push_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'skipped')),
  attempts INT NOT NULL DEFAULT 0,
  last_error TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(notification_id)
);

CREATE INDEX IF NOT EXISTS idx_notification_push_pending
ON public.notification_push_deliveries(status, created_at)
WHERE status IN ('pending', 'failed');

ALTER TABLE public.device_push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_push_deliveries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage their device push tokens" ON public.device_push_tokens;
CREATE POLICY "Users manage their device push tokens"
ON public.device_push_tokens FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Push deliveries readable by notification owner" ON public.notification_push_deliveries;
CREATE POLICY "Push deliveries readable by notification owner"
ON public.notification_push_deliveries FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  OR public.is_admin_or_super()
  OR public.has_permission('notifications.manage')
);

CREATE OR REPLACE FUNCTION public.register_device_push_token(
  p_token TEXT,
  p_platform TEXT DEFAULT 'unknown'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication is required' USING ERRCODE = '42501';
  END IF;

  IF NULLIF(trim(p_token), '') IS NULL THEN
    RAISE EXCEPTION 'Push token is required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.device_push_tokens (
    user_id,
    token,
    platform,
    is_active,
    last_seen_at
  )
  VALUES (
    auth.uid(),
    trim(p_token),
    COALESCE(NULLIF(trim(p_platform), ''), 'unknown'),
    true,
    NOW()
  )
  ON CONFLICT (token) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    platform = EXCLUDED.platform,
    is_active = true,
    last_seen_at = NOW()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.unregister_device_push_token(p_token TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.device_push_tokens
  SET is_active = false,
      last_seen_at = NOW()
  WHERE token = trim(p_token)
    AND user_id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.queue_notification_push_delivery()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notification_push_deliveries (notification_id, user_id)
  VALUES (NEW.id, NEW.user_id)
  ON CONFLICT (notification_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS queue_notification_push_delivery_trigger ON public.notifications;
CREATE TRIGGER queue_notification_push_delivery_trigger
AFTER INSERT ON public.notifications
FOR EACH ROW EXECUTE FUNCTION public.queue_notification_push_delivery();

CREATE OR REPLACE FUNCTION public.claim_pending_push_deliveries(p_limit INT DEFAULT 50)
RETURNS TABLE (
  delivery_id UUID,
  notification_id UUID,
  user_id UUID,
  title TEXT,
  body TEXT,
  data JSONB,
  tokens TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH claimed AS (
    SELECT d.id
    FROM public.notification_push_deliveries d
    WHERE d.status IN ('pending', 'failed')
      AND d.attempts < 5
    ORDER BY d.created_at
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100))
    FOR UPDATE SKIP LOCKED
  ),
  updated AS (
    UPDATE public.notification_push_deliveries d
    SET status = 'processing',
        attempts = attempts + 1,
        updated_at = NOW()
    FROM claimed
    WHERE d.id = claimed.id
    RETURNING d.id, d.notification_id, d.user_id
  )
  SELECT
    u.id AS delivery_id,
    n.id AS notification_id,
    n.user_id,
    n.title,
    n.body,
    n.data,
    COALESCE(array_agg(t.token) FILTER (WHERE t.token IS NOT NULL), ARRAY[]::TEXT[]) AS tokens
  FROM updated u
  JOIN public.notifications n ON n.id = u.notification_id
  LEFT JOIN public.device_push_tokens t
    ON t.user_id = n.user_id
   AND t.is_active = true
  GROUP BY u.id, n.id, n.user_id, n.title, n.body, n.data;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_push_delivery_result(
  p_delivery_id UUID,
  p_status TEXT,
  p_error TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_status NOT IN ('sent', 'failed', 'skipped') THEN
    RAISE EXCEPTION 'Invalid push delivery status' USING ERRCODE = '22023';
  END IF;

  UPDATE public.notification_push_deliveries
  SET status = p_status,
      last_error = p_error,
      sent_at = CASE WHEN p_status = 'sent' THEN NOW() ELSE sent_at END,
      updated_at = NOW()
  WHERE id = p_delivery_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.register_device_push_token(TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.unregister_device_push_token(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_pending_push_deliveries(INT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mark_push_delivery_result(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_device_push_token(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unregister_device_push_token(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_pending_push_deliveries(INT) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.mark_push_delivery_result(UUID, TEXT, TEXT) TO service_role, postgres;

NOTIFY pgrst, 'reload schema';
