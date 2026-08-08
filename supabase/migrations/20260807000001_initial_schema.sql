-- Migration: 20260807000001_initial_schema.sql
-- Description: Initial Schema & Security Infrastructure Reconciled for Phase 0.75
-- Canonical Roles: 'super_admin', 'admin', 'staff', 'teacher', 'parent', 'student'

-- 1. Create Canonical Enums
CREATE TYPE user_role AS ENUM ('super_admin', 'admin', 'staff', 'teacher', 'parent', 'student');
CREATE TYPE branch_status AS ENUM ('active', 'inactive', 'archived');

-- 2. Branches Table
CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    address TEXT,
    phone_number TEXT,
    status branch_status NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Profiles Table (Extends auth.users 1-to-1)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'student',
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    phone_number TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_branch_id ON public.profiles(branch_id);

-- 4. Minimal, Recursion-Safe Security Helper Functions (SECURITY DEFINER with pinned search_path)
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS user_role AS $$
DECLARE
    u_role user_role;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN NULL;
    END IF;
    SELECT role INTO u_role FROM public.profiles WHERE id = auth.uid();
    RETURN u_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_branch_id()
RETURNS UUID AS $$
DECLARE
    b_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN NULL;
    END IF;
    SELECT branch_id INTO b_id FROM public.profiles WHERE id = auth.uid();
    RETURN b_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_admin_or_super()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.current_user_role() IN ('admin', 'super_admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.current_user_role() = 'super_admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 6. Branches RLS Policies
CREATE POLICY "Allow read access to active branches for authenticated users"
    ON public.branches FOR SELECT
    TO authenticated
    USING (status = 'active' OR public.is_admin_or_super());

CREATE POLICY "Allow full management of branches to super_admin and admin"
    ON public.branches FOR ALL
    TO authenticated
    USING (public.is_admin_or_super())
    WITH CHECK (public.is_admin_or_super());

-- 7. Profiles RLS Policies
CREATE POLICY "Users can view own profile or branch profiles if staff/admin"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (
        id = auth.uid()
        OR public.is_super_admin()
        OR (
            public.current_user_role() IN ('admin', 'staff')
            AND branch_id = public.current_user_branch_id()
        )
    );

-- Self Profile Update Policy: Non-admins CANNOT alter role or branch_id
CREATE POLICY "Users can update own non-privileged profile details"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (
        id = auth.uid()
        AND (
            public.is_admin_or_super()
            OR (
                role = public.current_user_role()
                AND (branch_id IS NOT DISTINCT FROM public.current_user_branch_id())
            )
        )
    );

CREATE POLICY "Admins can insert or delete profiles"
    ON public.profiles FOR ALL
    TO authenticated
    USING (public.is_admin_or_super())
    WITH CHECK (public.is_admin_or_super());

-- 8. Updated At Trigger Function
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER update_branches_modtime
    BEFORE UPDATE ON public.branches
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER update_profiles_modtime
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 9. Auto Create Profile on Auth Signup Trigger
-- SECURITY CRITICAL: Public signup ALWAYS defaults to 'student'.
-- Metadata attempts to pass privileged roles (admin, super_admin, staff, teacher) are IGNORED.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role, branch_id)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
        'student'::user_role, -- Always default public signup to student
        (NEW.raw_user_meta_data->>'branch_id')::uuid
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
