# Phase 7 Attendance, Leave & Compensation Engine Specification & Architecture

## 1. Domain Overview
The Phase 7 Attendance Engine manages dated class occurrences (`class_sessions`), student roll call operations (`attendance_records`), leave excuse requests (`leave_requests`), and make-up session assignments (`compensation_requests`).

## 2. Schedule vs. Class Session Distinction
- **Schedule:** Recurring weekly group template (`schedules`).
- **Class Session:** Concrete dated occurrence (`class_sessions`).
- **Attendance Record:** Student attendance state for a specific session (`attendance_records`).

## 3. Server-Authoritative RPCs
- **`mark_session_attendance(p_session_id, p_records)`:** Atomically marks student attendance states (`present`, `absent`, `late`, `excused`) after verifying group enrollment and teacher assignment.
- **`finalize_session_attendance(p_session_id)`:** Auto-marks remaining unmarked active group students as `absent` and sets session status to `completed`.
- **`review_leave_request(p_request_id, p_decision, p_reviewer_note)`:** Updates leave status and automatically sets corresponding `attendance_records.attendance_status = 'excused'` if approved.

## 4. Quality Gate Verification
- **Database (pgTAP):** 52 / 52 passing assertions on live PostgreSQL stack.
- **Flutter Quality Gate:** 43 / 43 passing unit and widget tests with 0 analyzer issues.
