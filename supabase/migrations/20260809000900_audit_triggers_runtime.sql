-- Migration: 20260809000900_audit_triggers_runtime.sql
-- Description: Database-level audit logging for high-value operational tables.

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  table_name TEXT NOT NULL,
  record_id UUID,
  action TEXT NOT NULL CHECK (action IN ('insert', 'update', 'delete')),
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS table_name TEXT,
  ADD COLUMN IF NOT EXISTS record_id UUID,
  ADD COLUMN IF NOT EXISTS action TEXT,
  ADD COLUMN IF NOT EXISTS old_data JSONB,
  ADD COLUMN IF NOT EXISTS new_data JSONB,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.audit_logs
  ALTER COLUMN table_name SET NOT NULL,
  ALTER COLUMN action SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'audit_logs_action_check'
      AND conrelid = 'public.audit_logs'::regclass
  ) THEN
    ALTER TABLE public.audit_logs
      ADD CONSTRAINT audit_logs_action_check
      CHECK (action IN ('insert', 'update', 'delete'));
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_audit_logs_table_created
ON public.audit_logs(table_name, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_created
ON public.audit_logs(actor_id, created_at DESC);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Audit logs readable by security admins" ON public.audit_logs;
CREATE POLICY "Audit logs readable by security admins"
ON public.audit_logs FOR SELECT TO authenticated USING (
  public.is_admin_or_super()
  OR public.has_permission('audit.view')
  OR public.current_user_role() = 'staff'
);

CREATE OR REPLACE FUNCTION public.write_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_record_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_record_id := NULLIF(to_jsonb(OLD)->>'id', '')::UUID;
  ELSE
    v_record_id := NULLIF(to_jsonb(NEW)->>'id', '')::UUID;
  END IF;

  INSERT INTO public.audit_logs (
    actor_id,
    table_name,
    record_id,
    action,
    old_data,
    new_data
  )
  VALUES (
    auth.uid(),
    TG_TABLE_NAME,
    v_record_id,
    lower(TG_OP),
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  target_table TEXT;
BEGIN
  FOREACH target_table IN ARRAY ARRAY[
    'students',
    'parents',
    'teachers',
    'staff',
    'groups',
    'enrollments',
    'lessons',
    'homework',
    'exams',
    'class_sessions',
    'attendance_records',
    'leave_requests',
    'invoices',
    'payment_transactions',
    'role_permissions',
    'user_permission_overrides'
  ]
  LOOP
    IF to_regclass('public.' || target_table) IS NOT NULL THEN
      EXECUTE format('DROP TRIGGER IF EXISTS audit_%I_changes ON public.%I', target_table, target_table);
      EXECUTE format(
        'CREATE TRIGGER audit_%I_changes
         AFTER INSERT OR UPDATE OR DELETE ON public.%I
         FOR EACH ROW EXECUTE FUNCTION public.write_audit_log()',
        target_table,
        target_table
      );
    END IF;
  END LOOP;
END;
$$;

NOTIFY pgrst, 'reload schema';
