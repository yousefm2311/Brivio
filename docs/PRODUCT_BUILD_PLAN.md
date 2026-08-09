# Product Build Plan

## Product Direction
The application should become a premium programming academy platform for baccalaureate students, not a generic course app. The strongest differentiator is the student learning workspace: short lessons, PDFs, notes, code practice, progress, streaks, and teacher/parent visibility.

## Phase 1: Professional Student Experience
- Replace the basic student dashboard with a learning command center.
- Add course progress, streaks, XP, active path, next lesson, study time, and clear actions.
- Build Smart Study Workspace with PDF, Notebook, and Code tabs.
- Persist notebook drafts and code drafts locally first, then sync to Supabase later.
- Add empty/error/loading states that do not leave the student stuck.

## Phase 2: Curriculum And Content Runtime
- Connect the student dashboard to Supabase curriculum tables.
- Support lesson types: video, pdf, programming, quiz, text.
- Add lesson completion, resume position, resource access, and progress tracking.
- Add teacher upload flow for PDFs and resources through Supabase Storage.

## Phase 3: Code Playground
- Build a sandbox backend for running Python/C++ safely outside the Flutter app.
- Store submissions, run output, execution errors, timeouts, and teacher feedback.
- Add guided examples and line-by-line explanations.

## Phase 4: Smart Study Workspace Sync
- Add Supabase tables for notebooks, annotations, highlights, bookmarks, sticky notes, and study sessions.
- Sync notes across devices.
- Add Study Replay using lightweight event logs.
- Add teacher sharing with explicit student consent.

## Phase 5: Teacher, Parent, Admin Value
- Teacher dashboard: content publishing, homework, exams, attendance, student blockers, announcements.
- Parent dashboard: study time, completion, attendance, payment status, child progress.
- Admin dashboard: branches, groups, staff, subscriptions, revenue, support operations.

## Phase 6: Production Hardening
- Add RLS coverage for new study workspace tables.
- Add offline-first draft handling and retry queues.
- Add monitoring, crash reporting, audit logs, and payment reconciliation.
- Add full widget/integration tests for core student workflows.

## Current Implementation Notes
- Existing database, auth, academy, assessment, attendance, payments, and communication foundations are present.
- The test suite currently passes.
- The main gap is product-grade UX and the unique student learning workflow.
