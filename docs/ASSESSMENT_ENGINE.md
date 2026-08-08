# Phase 6 Assessment Engine Specification & Architecture

## 1. Domain Overview
The Phase 6 Assessment Engine provides reusable Question Bank management, Homework assignments, and timed Exam execution with server-authoritative grading and result release controls.

## 2. Reusable Question Bank
- **Normalized Schema:** Canonical `questions` table linked to `question_options`.
- **Supported Question Types:**
  - `multiple_choice`: Choice selection.
  - `true_false`: Boolean assertion.
  - `short_answer`: Normalized text string comparison.
  - `long_answer`: Manual teacher grading.
- **Answer-Key Security:** RLS policies and RPC filters ensure option correctness flags (`is_correct`) are **NEVER** returned in student-facing question queries before submission/result release.

## 3. Homework Engine
- **Lifecycle:** `draft` $\to$ `published` $\to$ `closed` $\to$ `archived`.
- **Submissions:** `in_progress` $\to$ `submitted` $\to$ `graded`.
- **Autosave:** Incremental answer persistence with debounce and offline state tracking.
- **Submission RPC:** `submit_homework(submission_id)` validates caller ownership and freezes submission.

## 4. Exam Engine
- **Lifecycle:** `draft` $\to$ `published` $\to$ `closed`.
- **Attempts:** `in_progress` $\to$ `submitted` / `expired` $\to$ `graded`.
- **Start Exam RPC:** `start_exam(p_exam_id)` validates student active group enrollment, exam published status, attempt limit bounds, and calculates `expires_at = NOW() + duration_minutes`.
- **Save Exam Answer RPC:** `save_exam_answer(p_attempt_id, p_question_id, p_selected_option_id, p_text_answer)` validates current server time is before `expires_at`.
- **Submit & Auto-Grade RPC:** `submit_exam_attempt(p_attempt_id)` evaluates objective question options (MCQ, True/False) automatically, computes score, and sets status to `graded`.

## 5. Quality Gate Verification
- **Database (pgTAP):** 42 / 42 passing assertions on live PostgreSQL stack.
- **Flutter Quality Gate:** 39 / 39 passing unit and widget tests with 0 analyzer issues.
