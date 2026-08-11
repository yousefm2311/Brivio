-- 1. Create a SQL script scratch/system_settings.sql that defines a key-value app_settings table and RPCs to get/set these global settings.

CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RPC to get admin setting
CREATE OR REPLACE FUNCTION public.get_admin_setting(setting_key TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_value JSONB;
BEGIN
  SELECT value INTO v_value FROM public.app_settings WHERE key = setting_key;
  RETURN v_value;
END;
$$;

-- RPC to set admin setting
CREATE OR REPLACE FUNCTION public.set_admin_setting(setting_key TEXT, setting_value JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.app_settings (key, value)
  VALUES (setting_key, setting_value)
  ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value, updated_at = NOW();
END;
$$;

-- Seed initial settings
INSERT INTO public.app_settings (key, value) VALUES
  ('email_digest', 'false'),
  ('two_factor_auth', 'false'),
  ('data_collection', 'false'),
  ('biometric_login', 'false')
ON CONFLICT (key) DO NOTHING;
