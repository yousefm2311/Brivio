# Educational Academy Platform - Feature Access Matrix (FEATURE_MATRIX.md)

Legend:
- `Y` = Permitted
- `N` = Denied
- `O` = Own Records Only / Assigned Scope Only
- `B` = Branch Scope Only

| Domain / Module | Action | super_admin | admin | staff | teacher | parent | student |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **System Settings** | view / update | Y | N | N | N | N | N |
| **Branches** | view | Y | Y | Y | B | B | B |
| **Branches** | create / update / delete | Y | B | N | N | N | N |
| **User Profiles** | view | Y | B | B | O | O | O |
| **User Profiles** | update | Y | B | B | O | O | O |
| **User Roles** | modify role enum | Y | B | N | N | N | N |
| **Subjects & Groups** | view | Y | Y | Y | B | B | B |
| **Subjects & Groups** | create / update | Y | B | B | N | N | N |
| **Enrollment** | view | Y | B | B | O | O | O |
| **Enrollment** | create / update / approve | Y | B | B | N | N | N |
| **Parent-Child Link** | create / update | Y | B | B | N | N | N |
| **Curriculum & Lessons**| view | Y | Y | Y | Y | N | O |
| **Curriculum & Lessons**| create / update | Y | B | N | O | N | N |
| **Curriculum & Lessons**| publish | Y | B | N | O | N | N |
| **Video & PDF Assets** | upload / delete | Y | B | N | O | N | N |
| **Video & PDF Assets** | download / view | Y | Y | Y | Y | Y | O |
| **Homework & Exams** | view | Y | B | B | O | O | O |
| **Homework & Exams** | create / update | Y | B | N | O | N | N |
| **Homework & Exams** | submit answer | N | N | N | N | N | Y |
| **Homework & Exams** | grade | Y | B | N | O | N | N |
| **Question Bank** | view / create / edit | Y | B | N | O | N | N |
| **Attendance** | view | Y | B | B | O | O | O |
| **Attendance** | record / update | Y | B | B | O | N | N |
| **Leave Requests** | view / create | Y | B | B | O | O | O |
| **Leave Requests** | approve | Y | B | B | N | N | N |
| **Compensation Session**| assign / schedule | Y | B | B | O | N | N |
| **Invoices & Billing** | view | Y | B | B | N | O | O |
| **Invoices & Billing** | create / approve | Y | B | B | N | N | N |
| **Payments** | make online payment | N | N | N | N | Y | Y |
| **Payments** | record cash receipt | Y | B | B | N | N | N |
| **Realtime Chat** | send / view messages | Y | Y | Y | O | O | O |
| **Notifications** | send broadcast | Y | B | B | O | N | N |
| **Analytics & Reports** | view global | Y | N | N | N | N | N |
| **Analytics & Reports** | view branch / group | Y | B | B | O | O | O |
| **Gamification Leaderboards**| view | Y | Y | Y | Y | Y | Y |
| **Code Playground** | execute code | Y | Y | Y | Y | N | Y |
| **PDF Reader & Notes** | view / create notes | Y | Y | N | O | N | O |
| **Study Replay Telemetry**| record / replay | Y | B | N | O | N | O |
