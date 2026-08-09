# Portal Market Readiness Audit

## Current Verdict
The project is not market-ready yet. The database and many feature foundations exist, but the five role portals are uneven. Several screens still use hardcoded IDs, incomplete workflows, weak empty/error handling, and operational UI that looks like internal scaffolding rather than a polished product.

## Cross-Portal Gaps
- Replace all hardcoded UUIDs in production screens with authenticated role/domain IDs and selected subject/group context.
- Standardize layout, navigation, loading, empty, error, and permission-denied states across all portals.
- Add production-grade onboarding and setup flows for branches, subjects, groups, teachers, students, parents, and enrollments.
- Add audit-visible feedback for every mutation: create, update, delete, publish, grade, payment, attendance, notification.
- Add mobile/tablet/desktop responsive QA for every portal.
- Add Arabic/English localization strategy before release.
- Add real analytics dashboards instead of raw counts.
- Add notification triggers for enrollment, lesson publishing, homework, exams, attendance, payments, and messages.
- Add full integration tests for role routing and critical workflows.

## Student Portal
### Present
- Auth-routed student dashboard.
- Active group listing.
- Real Supabase-backed learning snapshot for assigned published lessons.
- Smart Study Workspace foundation: PDF tab, notebook, code tab, local fallback, Supabase draft sync foundation.

### Missing
- Full lesson list by subject/unit, not only next lesson.
- Video lesson player and progress tracking.
- Real code execution sandbox for Python/C++.
- Homework submission UI.
- Exam runner entry points from student portal.
- Attendance history and leave request UI.
- Invoices/payments/receipts UI.
- Chat/announcements/notifications center.
- Gamification: XP, streaks, badges, leaderboard.
- PDF annotations: highlights, drawing over PDF, sticky notes, bookmarks UI.
- Study Replay recording and playback UI.
- Offline queue with conflict resolution.

## Parent Portal
### Present
- Lists linked children.
- Shows selected child groups.

### Missing
- Child progress dashboard.
- Attendance history and absence alerts.
- Grades, homework, exams, teacher feedback.
- Payments, invoices, receipts, and overdue alerts.
- Leave request creation and compensation lesson tracking.
- Teacher/staff messaging.
- Notifications.
- Multi-child comparison and per-child filters.
- Read-only review of study activity and completion.
- No meaningful error states; errors are swallowed.

## Teacher Portal
### Present
- Navigation shell for teaching, academic, operations, account.
- Assigned groups, schedule, curriculum, question bank, homework, exams, attendance, grading screens exist.

### Critical Issues
- Uses fallback teacher UUID when auth bootstrap has no teacherId.
- Several child screens use hardcoded subject/group/student IDs.
- Metrics are broad queries, not scoped correctly to assigned teacher data.

### Missing
- Teacher home should show actionable queue: today sessions, ungraded submissions, low-progress students, upcoming deadlines.
- Group detail analytics: completion, attendance, grades, blockers.
- Real resource upload UX for PDFs/videos with publish validation.
- Student study replay review with consent.
- Teacher comments on student notes.
- Lesson preview as student.
- Bulk announcements to groups.
- Robust grading workflow with rubrics and publish/unpublish results.
- No full responsive polish for mobile teacher use.

## Admin Portal
### Present
- Broad navigation for branches, subjects, groups, schedules, people, curriculum, assessments, attendance, finance, RBAC.
- Overview summary counts.

### Missing
- Market-grade dashboard: revenue, enrollment trends, active users, churn, arrears, academic performance.
- Branch-scoped filtering and global/branch switching.
- System settings.
- Audit logs UI.
- User provisioning workflow with invite/reset/suspend/reactivate.
- Data import/export.
- Operational setup wizard.
- Notification/broadcast management from admin shell.
- Support tools: impersonation-safe diagnostics, account recovery, payment reconciliation.
- Current design is dense NavigationRail CRUD; not yet polished SaaS admin UX.

## Staff Portal
### Present
- Shows students and groups if permissions allow.

### Missing
- Almost all staff operations:
  - Enrollment creation/approval.
  - Parent-child linking.
  - Attendance adjustments.
  - Leave approval.
  - Compensation scheduling.
  - Invoice generation.
  - Cash payment/receipt recording.
  - Student support profile.
  - Daily operations queue.
  - Search/filter/export.
- Errors are swallowed.
- No real navigation structure.

## Release Completion Plan
### Phase 1: Blockers And Data Integrity
- Remove all production hardcoded IDs.
- Fix silent catches and show actionable errors.
- Scope every query by authenticated role, branch, teacher assignment, parent-child link, or student enrollment.
- Add missing RLS policies for any new tables.
- Add integration tests for role access.

### Phase 2: Portal Shell Redesign
- Create a shared responsive portal shell with consistent top bar, side nav, bottom nav, page headers, breadcrumbs, and empty states.
- Apply it to admin, staff, teacher, parent, and student.
- Standardize cards, tables, filters, dialogs, forms, toasts, and confirmation flows.

### Phase 3: Student Product Completion
- Build subject/unit/lesson catalog.
- Complete Smart Study Workspace UI: bookmarks, highlights, drawing, sticky notes, split screen, progress.
- Add homework submission, exam runner, payment view, attendance/leave view, notifications, chat.
- Integrate code sandbox.

### Phase 4: Teacher Product Completion
- Replace hardcoded academic context with selected group/subject context.
- Complete curriculum publishing with PDF/video upload.
- Complete homework/exam creation, grading, analytics, announcements.
- Add student progress and study replay review.

### Phase 5: Parent Product Completion
- Build child overview, progress, grades, attendance, payments, leave requests, notifications, messaging.
- Add read-only study insights and per-child reporting.

### Phase 6: Admin And Staff Operations Completion
- Build admin analytics and setup workflows.
- Build staff daily operations queue.
- Complete enrollment, parent linking, compensation, payments, receipts, reconciliation, reports.
- Add audit log and support tooling.

### Phase 7: Production Hardening
- Full test coverage for critical workflows.
- Supabase migration validation in CI.
- Crash/error monitoring.
- Performance pass on large data tables.
- Localization.
- Security review for RLS and Edge Functions.
- Store-ready build, branding, icons, privacy policy, and release checklist.
