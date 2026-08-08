# Educational Academy Platform - Acceptance Criteria (ACCEPTANCE_CRITERIA.md)

## 1. Domain: Authentication & Role Enforcement
- [ ] User can sign in with valid email/password.
- [ ] System resolves canonical user role (`super_admin`, `admin`, `staff`, `teacher`, `parent`, `student`) from `public.profiles`.
- [ ] User session persists cleanly across app re-launches.
- [ ] Password reset email is sent when requested for registered email.
- [ ] Changing role in database immediately affects server-side RLS permissions.

## 2. Domain: Branches & RBAC Operations
- [ ] `super_admin` can create, update, and archive branches.
- [ ] `admin` and `staff` can manage subjects and groups within their assigned branch.
- [ ] `staff` can register students, link parents via `parent_child_links`, and approve enrollments.
- [ ] Unauthorized operations return Postgrest RLS error (HTTP 425/403) on database level.

## 3. Domain: Curriculum, Video & Interactive PDF Study
- [ ] Teachers can create Units and published Lessons with attached PDF/Video assets.
- [ ] Students can view published lessons belonging to their enrolled groups.
- [ ] Smart PDF viewer allows highlighting, text notes, and pencil drawings with auto-saving.
- [ ] Student notebook stores markdown notes per lesson.

## 4. Domain: Homework, Exams & Code Playground
- [ ] Teachers can build exams with MCQ and essay questions.
- [ ] Objective MCQ questions auto-graded upon submission; subjective essay questions enter teacher grading queue.
- [ ] Students can execute Python, JavaScript, Dart, and C++ code in Code Playground.
- [ ] Code execution times out after 5.0 seconds and enforces 128MB RAM limit.

## 5. Domain: Attendance, Billing & Analytics
- [ ] Teachers can record attendance (`present`, `absent`, `late`, `excused`).
- [ ] Parents can submit leave requests and view approved compensation lesson schedules.
- [ ] Automated invoices generated for tuition; parents can pay online or upload receipts.
- [ ] Admin analytics dashboard renders revenue metrics, pass rates, and branch enrollment trends.
