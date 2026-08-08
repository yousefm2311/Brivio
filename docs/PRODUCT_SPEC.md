# Educational Academy Platform - Product Specification (PRODUCT_SPEC.md)

## 1. System Overview & Vision

The Educational Academy Platform is an enterprise-grade multi-branch learning management system (LMS), student portal, teacher management environment, parent monitoring platform, and administrative control center.

The platform provides unified multi-role educational services including curriculum management, automated grading, live/recorded video streaming, interactive PDF smart study, isolated code playground execution, study replay telemetry, financial billing, attendance, and real-time messaging.

---

## 2. Canonical User Roles

The system recognizes 6 canonical, non-changeable system roles:
1. `super_admin` - Global system controller with cross-tenant, cross-branch, system configuration, database schema, and audit privileges.
2. `admin` - Branch or organization administrator responsible for multi-branch operations, staff oversight, billing, and subject management.
3. `staff` - Administrative operations staff handling student enrollment, schedules, attendance adjustments, payment processing, and leave requests.
4. `teacher` - Educators responsible for classroom group management, curriculum delivery, homework/exam grading, and student progress tracking.
5. `parent` - Guardians viewing linked children's attendance, grades, homework, billing, and direct teacher messaging.
6. `student` - Learners consuming curriculum, submitting homework, taking exams, executing code in the playground, annotating PDFs, and reviewing study replays.

---

## 3. Domain Specifications

### 3.1 Domain: Authentication & Identity Management
- **Actors:** `super_admin`, `admin`, `staff`, `teacher`, `parent`, `student`.
- **Preconditions:** Active network connection; user account created or registered with verified credentials.
- **Business Rules:**
  - Mandatory password policy: Minimum 8 characters, at least 1 uppercase letter, 1 number, and 1 special character.
  - Multi-factor authentication (MFA) supported for `super_admin` and `admin` roles.
  - JWT tokens issued by Supabase Auth with standard session duration and refresh token rotation.
- **Authorization Rules:**
  - Self-service signup creates unverified student accounts unless restricted by branch configuration.
  - Staff, Teacher, Admin, and Super Admin accounts must be created by an `admin` or `super_admin`.
- **Main Flow:**
  1. User submits email/username and password.
  2. System verifies credentials against Supabase Auth.
  3. Supabase Auth returns JWT containing user claims (`sub`, `aud`, `email`).
  4. System fetches linked `profiles` record to resolve canonical role (`user_role`).
  5. Application routes user to role-specific dashboard shell.
- **Alternate Flows:** Password reset via email OTP; SSO integration.
- **Failure Cases:** Invalid credentials (HTTP 400); Account disabled (HTTP 403); Rate limit exceeded (HTTP 429).
- **Data Ownership:** User credentials owned by Supabase Auth; Profile record owned by user (read/self-update) and managed by `admin`/`super_admin`.
- **Audit Requirements:** Log all login attempts, failed attempts, password resets, and session revocations.
- **Acceptance Criteria:** Users can sign in, request password reset, maintain session across app restarts, and sign out cleanly.

---

### 3.2 Domain: User Profiles & Branch Organization
- **Actors:** All Roles.
- **Preconditions:** Authenticated user session.
- **Business Rules:**
  - Every non-`super_admin` user belongs to at least 1 primary `branch`.
  - `super_admin` can manage all branches.
  - Profiles contain full name, email, phone number, avatar URL, role enum, and branch reference.
- **Authorization Rules:**
  - Users can read and update their own full name, phone number, and avatar URL.
  - Only `admin` and `super_admin` can change user role or assigned branch.
- **Data Ownership:** Profile records belong to the user ID (UUID matching `auth.users.id`).
- **Audit Requirements:** Audit role changes, branch reassignments, and account suspensions.
- **Acceptance Criteria:** Profile details updated instantly in DB with RLS preventing unauthorized field modification.

---

### 3.3 Domain: Branches, Subjects & Group Management
- **Actors:** `super_admin`, `admin`, `staff`, `teacher`.
- **Preconditions:** Branch exists and is active.
- **Business Rules:**
  - Branches organize groups, subjects, classrooms, and staff.
  - Subjects belong to branches or global templates.
  - Groups (classes) combine a Subject, assigned Teacher(s), Schedule, and enrolled Students.
- **Authorization Rules:**
  - `super_admin` creates/archives branches.
  - `admin` and `staff` manage subjects, groups, and schedules within their branch.
  - `teacher` views assigned groups and enrolled students.
- **Acceptance Criteria:** Admins can assemble groups, assign teachers, set capacity limits, and enforce enrollment constraints.

---

### 3.4 Domain: Enrollment & Scheduling
- **Actors:** `admin`, `staff`, `student`, `parent`.
- **Preconditions:** Group has open capacity; Student profile active.
- **Business Rules:**
  - Enrollment links a Student to a Group with an enrollment status (`active`, `pending`, `dropped`, `completed`).
  - Schedules define recurring time slots, room assignments, and online meeting links.
- **Authorization Rules:**
  - `staff` and `admin` approve enrollments and resolve schedule conflicts.
  - `student` and `parent` view schedule calendars.

---

### 3.5 Domain: Curriculum, Units, Lessons & Resources (Video & PDF)
- **Actors:** `admin`, `teacher`, `student`.
- **Preconditions:** Group or Subject defined.
- **Business Rules:**
  - Hierarchical curriculum: Subject $\rightarrow$ Unit $\rightarrow$ Lesson $\rightarrow$ Resource.
  - Resources include Video streams (HLS/MP4), PDF document assets, text guides, and links.
  - Lessons have sequence order and optional prerequisite completion requirements.
- **Authorization Rules:**
  - `teacher` and `admin` create, edit, publish, and order lessons.
  - `student` can view published lessons belonging to enrolled groups.
- **Acceptance Criteria:** Students stream video content and open interactive PDFs with real-time completion tracking.

---

### 3.6 Domain: Homework, Exams & Question Banks
- **Actors:** `teacher`, `student`, `parent`, `admin`.
- **Preconditions:** Published lesson/unit.
- **Business Rules:**
  - Question Banks support MCQ, Multi-select, True/False, Short Answer, Essay, and Code Execution question types.
  - Exams support time limits, randomized question ordering, auto-grading for objective questions, and manual teacher review for open-ended questions.
  - Homework has explicit submission deadlines, late penalty rules, and attachment uploads.
- **Authorization Rules:**
  - `teacher` creates question banks, builds exams/homework, and submits grades with feedback comments.
  - `student` submits answers before deadline.
  - `parent` views published grades and teacher feedback.

---

### 3.7 Domain: Attendance, Leave Requests & Compensation Lessons
- **Actors:** `teacher`, `staff`, `student`, `parent`, `admin`.
- **Preconditions:** Active group session scheduled.
- **Business Rules:**
  - Attendance statuses: `present`, `absent`, `late`, `excused`.
  - Parents or students submit Leave Requests with reason documentation.
  - `staff` or `teacher` approves leave requests and schedules Compensation Lessons.
- **Authorization Rules:**
  - `teacher` records session attendance.
  - `staff` updates leave request approvals and assigns compensation slots.

---

### 3.8 Domain: Payments, Subscriptions & Financial Invoicing
- **Actors:** `admin`, `staff`, `parent`, `student`.
- **Preconditions:** Enrolled student or subscription plan selected.
- **Business Rules:**
  - Invoices generated for monthly tuition, single course fees, or exam registration.
  - Payment statuses: `pending`, `paid`, `overdue`, `refunded`, `partially_paid`.
  - Supports credit card, bank transfer receipts, or manual cash record entry by staff.
- **Authorization Rules:**
  - `staff` and `admin` issue invoices, record manual payments, and process refunds.
  - `parent` and `student` view invoices, make online payments, and download PDF receipts.

---

### 3.9 Domain: Real-Time Chat & Push Notifications
- **Actors:** All Roles.
- **Preconditions:** Linked entity relationship (e.g., Parent-Teacher, Student-Teacher in same group, Group Broadcasts).
- **Business Rules:**
  - Direct 1-on-1 messaging and Group Channel channels.
  - Push notifications triggered for homework assignments, exam announcements, attendance alerts, payment reminders, and direct messages.
- **Authorization Rules:**
  - RLS policies restrict chat message access strictly to conversation participants.

---

### 3.10 Domain: Reports, Analytics & Gamification
- **Actors:** All Roles (Scoped).
- **Preconditions:** Historical telemetry data recorded.
- **Business Rules:**
  - Students earn XP, streak counters, badges, and leaderboard rankings based on lesson completion, homework submissions, and attendance consistency.
  - Analytics dashboards provide:
    - Admin: Revenue, branch enrollment trends, pass/fail rates.
    - Teacher: Group grade averages, completion bottlenecks.
    - Parent: Student progress reports, attendance metrics.

---

### 3.11 Domain: Code Playground & Isolated Execution Service
- **Actors:** `student`, `teacher`, `admin`.
- **Preconditions:** Code playground enabled for subject/lesson.
- **Business Rules:**
  - **Initial Production Scope Languages:** Python, C++.
  - *(Future Supported Languages: JavaScript, Dart, Java).*
  - Execution constraints: Memory limit 128MB, CPU limit 0.5 cores, Timeout 5.0 seconds, No arbitrary external network access.
- **Authorization Rules:**
  - Authenticated students execute code within rate-limited limits (e.g. max 10 executions/min).

---

### 3.12 Domain: Smart Study Workspace (PDF Reader, Notebook, Annotations, Telemetry & Study Replay)
- **Actors:** `student`, `teacher`.
- **Preconditions:** Enrolled student accessing lesson PDF or video resource.
- **Business Rules:**
  - **PDF Reader:** In-app PDF view with highlight text, sticky notes, drawing pencil, and bookmarks.
  - **Notebook:** Markdown & rich-text student note-taking synchronized with lesson timeline.
  - **Telemetry & Study Replay:** Client records interaction events (page view duration, video seek timestamps, code execution attempts, note timestamps).
  - **Study Replay:** Teachers and students can replay past study sessions as a time-synced telemetry playback.
- **Authorization Rules:**
  - Personal notes and annotations owned by student (private unless explicitly shared with teacher).
