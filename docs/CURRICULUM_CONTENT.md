# Phase 5 — Curriculum & Content Engine Specification

## 1. Curriculum Hierarchy Model
The canonical hierarchical model for educational learning content in the platform is strictly defined as:
```text
Subject
 └── Semester
      └── Unit
           └── Lesson
                └── Lesson Resource
```

### Relational Schema Bounds
- `semesters.subject_id` $\to$ `subjects.id`
- `units.semester_id` $\to$ `semesters.id` (No duplicated `units.subject_id`)
- `lessons.unit_id` $\to$ `units.id`
- `lesson_resources.lesson_id` $\to$ `lessons.id`

---

## 2. Lesson Lifecycle & Status State Machine
Lessons transition through a strict typed lifecycle:
1. `draft`: Editable by authorized teachers and administrators. Invisible to student learning portals.
2. `published`: Active educational content accessible by students actively enrolled in the subject.
3. `archived`: Read-only historical content excluded from normal navigation but preserving progress records.

---

## 3. Student Content Access Security Architecture
Access to published curriculum content is strictly controlled through server-side database RLS and helper functions (`current_student_can_access_lesson(p_lesson_id)`):
- Access is granted **only** if the student possesses an `active` enrollment in a `group` linked to the `subject` containing the lesson.
- Global access to published lessons is strictly prohibited.

---

## 4. Lesson Progress & Resume Architecture
- **Atomic Server RPC:** `update_lesson_progress(p_lesson_id, p_status, p_progress_percentage, p_last_position_seconds, p_time_spent_seconds)`
- Derives student ID internally from `auth.uid()` (prevents student ID spoofing).
- Bounded progress: `0 <= progress_percentage <= 100`.
- Single progress record per `(student_id, lesson_id)` pair maintained via database `ON CONFLICT` upserts.

---

## 5. Storage Architecture & Asset Protection
- **Private Storage Bucket:** `curriculum_assets` (File size limit: 100 MB).
- **Access Rule:** Default `public = false`. Private educational files (MP4, PDF, PNG) are downloaded or streamed via short-lived signed URLs.
