# Production Authentication & Authorization Architecture (docs/AUTHENTICATION.md)

## 1. Authentication Architecture & Session Lifecycle
- **SDK & Provider:** Powered by Supabase Auth (`supabase_flutter`) integrated with custom PostgreSQL profile and permission extensions.
- **Session Restoration:** On application startup, `AuthViewModel.restoreSession()` queries `SupabaseClient.auth.currentUser`. If a session JWT exists, it invokes the PostgreSQL RPC contract `get_current_user_bootstrap()` to load the profile, canonical role, account status, and effective permissions list in a single race-free network call.
- **Token Security:** Session tokens are securely managed by Supabase SDK (`flutter_secure_storage` encrypted local storage). Service-role keys are **NEVER** embedded in client application code.

---

## 2. Canonical Role Model & Serialization
- **System Roles (6):** `super_admin`, `admin`, `staff`, `teacher`, `parent`, `student`.
- **Serialization Mapping:**
  - `UserRole.superAdmin` $\leftrightarrow$ `'super_admin'`
  - `UserRole.admin` $\leftrightarrow$ `'admin'`
  - `UserRole.staff` $\leftrightarrow$ `'staff'`
  - `UserRole.teacher` $\leftrightarrow$ `'teacher'`
  - `UserRole.parent` $\leftrightarrow$ `'parent'`
  - `UserRole.student` $\leftrightarrow$ `'student'`
- Unknown database role strings fail safely without elevating privileges.

---

## 3. Public Self-Registration vs Privileged Provisioning
- **Public Signup:** Public self-registration is strictly restricted to creating `student` accounts. Database trigger `handle_new_user()` enforces `role = 'student'::user_role` for all public signups regardless of client metadata.
- **Privileged Account Provisioning:** Privileged accounts (`super_admin`, `admin`, `staff`, `teacher`) MUST be provisioned by an authorized administrator using the PostgreSQL RPC `public.provision_privileged_user(p_email, p_full_name, p_role, p_branch_id)`.
  - `super_admin` callers can provision `admin`, `staff`, and `teacher` roles.
  - `admin` callers can provision `staff` and `teacher` roles.
  - Non-privileged callers (students, parents, teachers, staff) calling `provision_privileged_user` are denied with `SQLSTATE 42501 (Unauthorized)`.

---

## 4. Current-User Bootstrap Contract (`get_current_user_bootstrap()`)
The single startup RPC contract returns a JSON payload containing:
- `profile`: Profile model fields (`id`, `email`, `full_name`, `avatar_url`, `phone_number`, `role`, `branch_id`, `status`, timestamps).
- `canonical_role`: Exact system role.
- `primary_branch_id`: User's primary branch assignment.
- `account_status`: `active`, `inactive`, or `suspended`.
- `effective_permissions`: Array of permission codes computed via 5-stage precedence.
- `domain_identity`: Linked domain IDs (`student_id`, `parent_id`, `teacher_id`).

---

## 5. 5-Stage Deterministic Permission Precedence
1. `super_admin` Role Authority $\to$ **GRANT (All Permissions)**
2. Explicit User DENY (`user_permissions.effect = 'deny'`) $\to$ **DENY**
3. Explicit User GRANT (`user_permissions.effect = 'grant'`) $\to$ **GRANT**
4. Role Baseline Permission (`role_permissions`) $\to$ **GRANT**
5. Default Fallback $\to$ **DENY**

---

## 6. Account Status Semantics & Portal Isolation
- **Account Statuses:** `active`, `inactive`, `suspended`.
- **Restricted Access:** If a valid JWT exists but `profile.status = suspended`, application access is restricted (`AuthStatus.restricted`) and user is routed to `Account Restricted Screen`.
- **Portal Isolation:** `RbacGuard.canAccessPortal` enforces target portal UX boundaries (Student Portal, Teacher Portal, Parent Portal, Staff Portal, Admin Dashboard).
- **Security Boundary:** `RbacGuard` and `PermissionGate` are UI/navigation convenience gates ONLY. PostgreSQL RLS policies remain the sole authoritative security boundary for data access.
