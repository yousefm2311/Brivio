# Educational Academy Platform - User Flows (USER_FLOWS.md)

## 1. Authentication & Onboarding Flows

### Flow 1.1: User Login & Role Routing
- **Actor:** All Roles.
- **Steps:**
  1. User opens Student, Teacher, Parent, or Admin app.
  2. User enters credentials (email & password).
  3. App calls Supabase Auth `signInWithPassword`.
  4. System fetches `public.profiles` record matching user UUID.
  5. App verifies role:
     - If role matches target app (or user is `super_admin`/`admin`), navigate to role dashboard shell.
     - If role mismatch, display error banner or redirect to appropriate role portal.

### Flow 1.2: Password Reset Recovery
- **Actor:** All Roles.
- **Steps:**
  1. User clicks "Forgot Password" on login screen.
  2. User inputs registered email address.
  3. System sends OTP/Reset email link via Supabase Auth.
  4. User clicks email link, opens app reset view, and provides new compliant password.
  5. Password updated in database; user directed back to login.

---

## 2. Administrative & Operational Flows

### Flow 2.1: Student Enrollment (Staff / Admin)
- **Actor:** `staff`, `admin`.
- **Steps:**
  1. Staff opens Student Directory in Branch view.
  2. Clicks "New Enrollment".
  3. Selects Student, Subject, and target Group.
  4. System verifies group capacity limit.
  5. Creates `enrollments` row in DB; generates initial tuition invoice.
  6. Sends confirmation notification to Student and linked Parent.

### Flow 2.2: Teacher Assignment & Group Creation (Admin)
- **Actor:** `admin`, `super_admin`.
- **Steps:**
  1. Admin opens Group Management.
  2. Selects Branch and Subject.
  3. Fills group code, schedule recurrence pattern, classroom room, and assigns primary Teacher.
  4. System inserts `groups` record and updates teacher schedule calendar.

### Flow 2.3: Parent-Child Account Linking (Staff / Admin)
- **Actor:** `staff`, `admin`.
- **Steps:**
  1. Staff views Parent Profile.
  2. Searches for Student by student code or national ID.
  3. Confirms relationship type (Father, Mother, Guardian).
  4. Inserts record into `parent_child_links`.
  5. Parent dashboard immediately updates with linked child's analytics.

---

## 3. Educator & Learning Content Flows

### Flow 3.1: Lesson Creation & Publishing (Teacher)
- **Actor:** `teacher`, `admin`.
- **Steps:**
  1. Educator opens Group Curriculum tab.
  2. Clicks "Add Unit" or "Add Lesson".
  3. Entitles lesson, uploads PDF resource file or attaches video URL.
  4. Adds optional code snippet exercise or homework assignment.
  5. Toggles state from `draft` to `published`.
  6. Students in enrolled group receive new content notification.

### Flow 3.2: Exam Creation & Automated/Manual Grading (Teacher)
- **Actor:** `teacher`.
- **Steps:**
  1. Teacher selects Question Bank, picks questions (MCQ, essay, code runner).
  2. Configures exam time limit (e.g. 60 mins) and start/end availability window.
  3. Students submit exam attempt before deadline.
  4. System auto-grades MCQ/True-False questions instantly.
  5. Teacher opens Grading Queue, reviews subjective essay answers, inputs score + feedback, and publishes final result.

---

## 4. Student Learning & Workspace Flows

### Flow 4.1: Interactive PDF Study & Notebook Annotations (Student)
- **Actor:** `student`.
- **Steps:**
  1. Student opens assigned Lesson in Student App.
  2. Opens PDF document viewer.
  3. Highlights text excerpts, creates sticky notes, and sketches diagrams with pencil tool.
  4. Student opens side-by-side Notebook, writes markdown summary notes.
  5. All annotations and notes auto-saved to DB under student profile.

### Flow 4.2: Code Playground Execution (Student)
- **Actor:** `student`.
- **Steps:**
  1. Student navigates to Code Playground tab or in-lesson code exercise.
  2. Chooses language runtime (Python, JS, Dart, C++).
  3. Types source code into code editor.
  4. Presses "Run Code".
  5. Request sent to Code Execution service API.
  6. Service runs code inside ephemeral Docker container and returns stdout/stderr/execution time.
  7. Editor renders terminal output window.

### Flow 4.3: Study Replay Telemetry Session (Student & Teacher)
- **Actor:** `student`, `teacher`.
- **Steps:**
  1. During study session, client captures time-series events (page flips, video pauses, code execution attempts, note keystrokes).
  2. Telemetry payload pushed to `study_telemetry_events` table.
  3. Teacher or Student opens "Study Replay" tab.
  4. Replay player reconstructs the student's exact learning sequence timeline with play/pause/seek controls.

---

## 5. Attendance & Financial Flows

### Flow 5.1: Recording Attendance & Leave Requests
- **Actor:** `teacher`, `parent`, `staff`.
- **Steps:**
  1. Teacher opens active group session roster, marks students `present`, `absent`, or `late`.
  2. If parent submitted a Leave Request in advance, system flags student as `excused_pending`.
  3. Staff reviews parent leave request attachment, clicks "Approve", and schedules a Compensation Lesson slot.

### Flow 5.2: Payment Processing & Invoicing
- **Actor:** `parent`, `student`, `staff`.
- **Steps:**
  1. Invoice generated automatically on 1st of month or manually by Staff.
  2. Parent opens Payment tab, views outstanding invoice.
  3. Selects online payment (Credit Card / Gateway) or uploads bank transfer receipt screenshot.
  4. System updates invoice status to `paid` and issues PDF receipt.
