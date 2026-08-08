# Security Architecture & Boundary Policies (docs/SECURITY.md)

## 1. Security Boundaries & Principles
- **PostgreSQL RLS is Authoritative:** All security rules, data isolation, and capability authorizations are enforced at the database level using Row Level Security (RLS) policies and `SECURITY DEFINER` functions with pinned `search_path = public`.
- **Client-Side UX-Only Boundaries:** Flutter navigation guards (`RbacGuard`), role checks, and UI widgets (`PermissionGate`, `RoleGate`) provide UI/navigation convenience ONLY. They are not security boundaries.
- **Zero Client-Side Service Keys:** `SUPABASE_SERVICE_ROLE_KEY` is **NEVER** embedded or compiled into client application bundles. Privileged user creation is handled via authorized RPC functions (`provision_privileged_user`) or secure server-side boundaries.

---

## 2. Public Self-Registration Protection
- Database trigger `public.handle_new_user()` overrides all client metadata and forces `role = 'student'::user_role` for all public signups.
- Malicious payloads containing `{"role": "super_admin"}` or `{"role": "admin"}` during public signup are safely neutralized by the database trigger.

---

## 3. Privileged Account Provisioning Authorization
- `public.provision_privileged_user()` RPC verifies caller identity (`auth.uid()`) before provisioning privileged users:
  - `super_admin` callers can provision `admin`, `staff`, and `teacher` accounts.
  - `admin` callers can provision `staff` and `teacher` accounts.
  - Unprivileged callers (students, parents, teachers, staff) attempting provisioning are denied with `SQLSTATE 42501`.

---

## 4. Account Status Enforcement
- Sessions where `status = 'suspended'` are blocked at the application level (`AuthStatus.restricted`), preventing suspended users from accessing dashboard UI or performing domain actions.
