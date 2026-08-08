# Current Implementation Reconciliation Audit (CURRENT_IMPLEMENTATION_REVIEW.md)

## Executive Summary
This document logs the reconciliation status of all discrepancies identified between the initial implementation and Phase 0 specifications (`PRODUCT_SPEC.md`, `USER_ROLES.md`, `FEATURE_MATRIX.md`).

---

## 1. Discrepancy Reconciliation Log

### 1.1 Canonical User Role Identifiers
- **Initial State:** Enum missing `staff` role; mapped `'superadmin'` to `UserRole.admin`.
- **Status:** **[RESOLVED]**
- **Action Taken:**
  - `UserRole` enum updated to canonical 6 roles: `superAdmin`, `admin`, `staff`, `teacher`, `parent`, `student`.
  - `toDbValue()` outputs exact PostgreSQL enum strings: `'super_admin'`, `'admin'`, `'staff'`, `'teacher'`, `'parent'`, `'student'`.
  - `UserRole.fromString()` handles `'super_admin'`, `'superadmin'`, `'super-admin'`, `'admin'`, `'staff'`, `'teacher'`, `'parent'`, `'student'`.

### 1.2 Database Migration & RLS Security
- **Initial State:** `20260807000001_initial_schema.sql` used `('admin', 'superadmin')`, omitted `staff`, lacked pinned `search_path` on functions, and lacked `WITH CHECK` protection on profile self-updates.
- **Status:** **[RESOLVED]**
- **Action Taken:**
  - Migration script rewritten with canonical `user_role` PostgreSQL enum: `('super_admin', 'admin', 'staff', 'teacher', 'parent', 'student')`.
  - Added helper function `public.get_user_role(user_id)` with explicit `SECURITY DEFINER SET search_path = public`.
  - Self-profile `UPDATE` RLS policy enhanced with `WITH CHECK` preventing non-admins from mutating `role` or `branch_id`.
  - Trigger function `handle_new_user()` updated to safely parse `user_role` with default fallback and explicit `search_path = public`.

### 1.3 Target Entry Points & App Shells
- **Initial State:** No target app entry point or dashboard shell existed for `staff`.
- **Status:** **[RESOLVED]**
- **Action Taken:**
  - Added `lib/apps/staff/main_staff.dart` and `lib/apps/staff/staff_dashboard.dart`.
  - Integrated `Operations Staff Application` launcher into `lib/main.dart` dev portal selector.

### 1.4 Client-Side RBAC Security Boundaries
- **Initial State:** Documentation and comments described `RbacGuard` as a security boundary preventing privilege escalation.
- **Status:** **[RESOLVED]**
- **Action Taken:**
  - `RbacGuard` comments updated to explicitly state it is **UX / Navigation protection ONLY** and NOT an authorization boundary.
  - Backend PostgreSQL RLS policies established as the single authoritative security boundary.

### 1.5 Unit Test Assumptions
- **Initial State:** Unit tests asserted `'superadmin'` mapping and lacked tests for `staff` or profile security.
- **Status:** **[RESOLVED]**
- **Action Taken:**
  - `user_role_test.dart` updated to assert all 6 canonical roles.
  - `rbac_guard_test.dart` updated for all 6 roles.
  - Added `profile_security_test.dart` verifying non-admin self-promotion prevention.

---

## 2. Status Summary Table

| Identified Discrepancy | Previous Issue | Reconciliation Status | Corrective Action |
| :--- | :--- | :---: | :--- |
| **Role Enum Mismatch** | Missing `staff`, wrong `superadmin` string | **RESOLVED** | Updated `UserRole` enum and database mapping |
| **PostgreSQL Enum** | `'superadmin'` without underscore | **RESOLVED** | Updated migration script to `'super_admin'` |
| **Missing Staff Portal** | No target app for `staff` role | **RESOLVED** | Added `lib/apps/staff/` target entry point & shell |
| **Client RBAC Boundary** | Claimed Flutter guard prevents privilege escalation | **RESOLVED** | Corrected docs to declare UX-only boundary |
| **Profile RLS Security** | No `WITH CHECK` preventing role self-mutation | **RESOLVED** | Added RLS `WITH CHECK` clause & `search_path` pinning |
| **Unit Test Coverage** | Missing 6-role assertions | **RESOLVED** | Updated test suite; all 21 tests passing |
