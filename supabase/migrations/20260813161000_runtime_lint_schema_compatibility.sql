-- Runtime compatibility columns required by the latest RPCs.
-- These are additive and safe on already-created projects.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS first_name TEXT,
  ADD COLUMN IF NOT EXISTS last_name TEXT;

UPDATE public.profiles
SET first_name = COALESCE(
      NULLIF(first_name, ''),
      NULLIF(split_part(COALESCE(full_name, ''), ' ', 1), '')
    ),
    last_name = COALESCE(
      NULLIF(last_name, ''),
      NULLIF(trim(substr(COALESCE(full_name, ''), length(split_part(COALESCE(full_name, ''), ' ', 1)) + 1)), '')
    )
WHERE first_name IS NULL
   OR last_name IS NULL;

ALTER TABLE public.account_login_qr_tokens
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.question_options
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.group_teachers
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

UPDATE public.group_teachers
SET is_active = (effective_from <= CURRENT_DATE)
                AND (effective_to IS NULL OR effective_to >= CURRENT_DATE);

ALTER TABLE public.enrollments
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'EGP',
  ADD COLUMN IF NOT EXISTS original_price_minor BIGINT;

UPDATE public.enrollments
SET original_price_minor = COALESCE(original_price_minor, base_price_minor, final_price_minor, 0),
    currency = COALESCE(NULLIF(currency, ''), 'EGP');

ALTER TABLE public.homework_answers
  ADD COLUMN IF NOT EXISTS is_correct BOOLEAN,
  ADD COLUMN IF NOT EXISTS points_awarded NUMERIC(6,2) NOT NULL DEFAULT 0.00;

-- Keep the additive columns fresh for new/updated rows.
CREATE OR REPLACE FUNCTION public.touch_question_option_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_touch_question_option_updated_at ON public.question_options;
CREATE TRIGGER tr_touch_question_option_updated_at
BEFORE UPDATE ON public.question_options
FOR EACH ROW
EXECUTE FUNCTION public.touch_question_option_updated_at();

CREATE OR REPLACE FUNCTION public.touch_account_login_qr_token_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_touch_account_login_qr_token_updated_at
ON public.account_login_qr_tokens;
CREATE TRIGGER tr_touch_account_login_qr_token_updated_at
BEFORE UPDATE ON public.account_login_qr_tokens
FOR EACH ROW
EXECUTE FUNCTION public.touch_account_login_qr_token_updated_at();

NOTIFY pgrst, 'reload schema';
