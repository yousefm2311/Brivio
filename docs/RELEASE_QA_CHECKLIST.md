# Release QA Checklist

Use this checklist before deploying the academy app in real centers. Automated tests are necessary, but production readiness also needs real device, real backend, and role-based UAT checks.

## Automated Gates

- Run `flutter pub get`.
- Run `flutter analyze lib test` and ship only when it returns `No issues found`.
- Run `flutter test` and ship only when all tests pass.
- Run `flutter build apk --debug` during development verification.
- Run `flutter build apk --release` for Android release verification.
- Run iOS release build on macOS with the production bundle id and signing profile.
- Run web/desktop builds only for the platforms enabled for the center.

## Backend Gates

- Apply database migrations with `supabase db push`.
- Deploy required Edge Functions:
  - `provision-user`
  - `admin-set-user-password`
  - `complete-account-login-qr`
  - notification/payment functions used by the production project
- Verify Supabase secrets for service-role access and external providers.
- Verify RLS policies for student, parent, teacher, staff, admin, and super admin.
- Seed one production-like center with branches, rooms, subjects, groups, schedules, students, parents, teachers, staff, invoices, exams, lessons, and board content.

## Platform And Permissions

- Android: camera QR, biometric, notification permission on Android 13+, network access, denied-permission paths.
- iOS: camera QR, Face ID, APNs push token, foreground/background notification delivery.
- macOS: network, camera, location entitlement prompts where enabled.
- Windows/Linux: confirm unsupported Firebase Messaging paths fail gracefully and do not block login.
- Test app restart after login, after biometric unlock, and after notification tap.

## Firebase Notifications

- Confirm every device registers and stores an FCM/APNs token.
- Send test notifications to student, parent, teacher, staff, and admin accounts.
- Validate notification tap routing to the correct screen: lesson, exam, payment receipt, attendance, schedule, help desk ticket, and announcement.
- Verify reminders for group schedule times reach both student and linked parent.
- Verify no user receives notifications for another branch/group/child.

## Admin UAT

- Create and edit branches, rooms, subjects, semesters, units, lessons, and resources.
- Create groups with capacity, schedule, room, teacher, subject, and branch.
- Confirm a full group blocks extra enrollment unless an admin explicitly changes capacity.
- Create student, parent, teacher, and staff accounts with optional password.
- Generate login QR for each role, complete first login, force password setup, and sign in later with password.
- Reset a user's password from admin.
- Link parent to one or more children and verify the parent portal immediately.
- Record cash payments and view electronic receipts.
- Review finance, attendance, exam, and teacher reports.

## Teacher UAT

- Open classes/workspace/curriculum without unexpected errors.
- Create lessons and upload PDF/resource content.
- Open lesson PDF and board side by side.
- Draw teacher explanation on board, save it, then verify student sees teacher board for the same group and lesson.
- Confirm student private board/notes do not overwrite teacher explanation or other students' work.
- Create exams/homework from question bank and publish to the correct group.
- Record attendance for a scheduled session and verify student/parent visibility.
- Review teacher finance and performance reports.
- Use help desk and notifications pages.

## Student UAT

- Login by QR, set password, logout, login by password.
- Login with biometric after enabling it, then test failure/cancel fallback.
- Open Learn, select teacher group, and see content grouped by semester/unit/lesson order.
- Open PDF and verify progress tracking is based on meaningful reading interaction, not only a quick full scroll.
- Open Board and confirm teacher explanation appears.
- Add private notes/drawings and verify they remain private to that student.
- Take exams/homework, submit answers, and see grades/solutions when released.
- View schedule, attendance, payment receipts, notifications, help desk, profile, and settings.
- Test Arabic and English labels, errors, and empty states.

## Parent UAT

- Login by QR, set password, logout, login by password.
- See all linked children immediately after admin linking.
- For each child, view schedule, attendance, exams, grades, submitted answers, and released solutions.
- View payment invoices and electronic receipts.
- Receive and open notifications for schedules, absence, exams, grades, and payments.
- Use help desk and verify tickets are associated with the correct child when needed.

## Staff UAT

- Login by password or QR according to account setup.
- Verify staff permissions only expose assigned operations.
- Generate QR/password reset only when allowed by role permissions.
- Confirm staff cannot access admin-only financial or security screens unless explicitly permitted.

## Regression Areas

- Auth session restore and role routing.
- Parent-child linking and group membership queries.
- Teacher board vs student private board storage keys.
- Payment receipt rendering for student, parent, teacher, and admin views.
- Notification routing.
- Error handling and retry actions on every empty/error screen.
- RTL Arabic layout, long text overflow, and small Android screens.
- Code playground runtime delay and algorithm visualization states.

## Release Decision

Ship only when:

- Automated gates pass.
- Real-device QR, biometric, push notification, and receipt flows pass.
- Admin, teacher, student, parent, and staff UAT pass on production-like data.
- Known unresolved issues are documented with owner, severity, and release decision.
