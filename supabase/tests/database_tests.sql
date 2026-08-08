-- pgTAP Database Test Suite for Academy Application Foundation & Phase 8.5 Financial Security Engine
BEGIN;

SELECT plan(80);

-- 1. Test user_role enum existence
SELECT has_type('user_role', 'user_role enum exists');

-- 2. Test primary key constraint on profiles matches auth.users
SELECT col_is_pk('profiles', 'id', 'profiles table uses id as PK');

-- 3. Test unique constraint on students.student_code
SELECT col_is_unique('students', 'student_code', 'student_code is unique');

-- 4. Test unique constraint on subjects.code
SELECT col_is_unique('subjects', 'code', 'subjects code is unique');

-- 5. Test group_teachers table existence
SELECT has_table('group_teachers', 'group_teachers table exists');

-- 6. Test btree_gist extension presence
SELECT has_extension('btree_gist', 'btree_gist extension enabled');

-- 7. Test unique ordering indexes on curriculum hierarchy
SELECT has_index('semesters', 'idx_semesters_subject_order', 'Semesters unique order index exists');
SELECT has_index('units', 'idx_units_semester_order', 'Units unique order index exists');
SELECT has_index('lessons', 'idx_lessons_unit_order', 'Lessons unique order index exists');

-- 8. Test permission_effect enum existence
SELECT has_type('permission_effect', 'permission_effect enum exists');

-- 9. Test has_permission RPC existence
SELECT has_function('has_permission', ARRAY['text'], 'has_permission RPC exists');

-- 10. Test current_student_id RPC existence
SELECT has_function('current_student_id', 'current_student_id RPC exists');

-- 11. Test current_parent_id RPC existence
SELECT has_function('current_parent_id', 'current_parent_id RPC exists');

-- 12. Test current_teacher_id RPC existence
SELECT has_function('current_teacher_id', 'current_teacher_id RPC exists');

-- 13. Test current_teacher_assigned_to_group RPC existence
SELECT has_function('current_teacher_assigned_to_group', ARRAY['uuid'], 'current_teacher_assigned_to_group RPC exists');

-- 14. Schedule creation validation - Invalid end_time <= start_time
PREPARE bad_schedule_time AS
INSERT INTO public.schedules (group_id, day_of_week, start_time, end_time)
VALUES ('c1000000-0000-0000-0000-000000000001', 1, '14:00:00', '13:00:00');
SELECT throws_ok('bad_schedule_time', '23514', NULL, 'Schedule creation fails when end_time <= start_time');

-- 15. Schedule creation validation - Valid schedule succeeds
INSERT INTO public.schedules (id, group_id, day_of_week, start_time, end_time)
VALUES ('d1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 1, '10:00:00', '11:30:00');
SELECT ok(true, 'Valid schedule slot creation succeeds');

-- 16. Test validate_and_create_schedule RPC existence
SELECT has_function('validate_and_create_schedule', ARRAY['uuid', 'int', 'time', 'time', 'text'], 'validate_and_create_schedule RPC exists');

-- 17. Test enroll_student_in_group RPC existence
SELECT has_function('enroll_student_in_group', ARRAY['uuid', 'uuid'], 'enroll_student_in_group RPC exists');

-- 18. Test get_student_list RPC existence
SELECT has_function('get_student_list', ARRAY['text', 'uuid', 'text', 'int', 'int'], 'get_student_list RPC exists');

-- 19. Test get_parent_list RPC existence
SELECT has_function('get_parent_list', ARRAY['text', 'int', 'int'], 'get_parent_list RPC exists');

-- 20. Test get_teacher_list RPC existence
SELECT has_function('get_teacher_list', ARRAY['text', 'uuid', 'int', 'int'], 'get_teacher_list RPC exists');

-- 21. Test current_student_can_access_lesson RPC existence
SELECT has_function('current_student_can_access_lesson', ARRAY['uuid'], 'current_student_can_access_lesson RPC exists');

-- 22. Test update_lesson_progress RPC existence
SELECT has_function('update_lesson_progress', ARRAY['uuid', 'text', 'int', 'int', 'int'], 'update_lesson_progress RPC exists');

-- 23. Test reorder_lessons RPC existence
SELECT has_function('reorder_lessons', ARRAY['uuid', 'uuid[]'], 'reorder_lessons RPC exists');

-- 24. Test storage bucket curriculum_assets exists and is private
SELECT is(
    (SELECT public FROM storage.buckets WHERE id = 'curriculum_assets'),
    false,
    'Storage bucket curriculum_assets is private'
);

-- 25. System/Admin lesson access check test
SELECT is(
    public.current_student_can_access_lesson('60000000-0000-0000-0000-000000000001'),
    true,
    'System/Admin context can access published lesson'
);

-- 26. Test reorder_semesters RPC existence
SELECT has_function('reorder_semesters', ARRAY['uuid', 'uuid[]'], 'reorder_semesters RPC exists');

-- 27. Test reorder_units RPC existence
SELECT has_function('reorder_units', ARRAY['uuid', 'uuid[]'], 'reorder_units RPC exists');

-- 28. Test reorder_lesson_resources RPC existence
SELECT has_function('reorder_lesson_resources', ARRAY['uuid', 'uuid[]'], 'reorder_lesson_resources RPC exists');

-- 29. Test questions table existence
SELECT has_table('questions', 'questions table exists');

-- 30. Test question_options table existence
SELECT has_table('question_options', 'question_options table exists');

-- 31. Test homework table existence
SELECT has_table('homework', 'homework table exists');

-- 32. Test homework_submissions table existence
SELECT has_table('homework_submissions', 'homework_submissions table exists');

-- 33. Test exams table existence
SELECT has_table('exams', 'exams table exists');

-- 34. Test exam_attempts table existence
SELECT has_table('exam_attempts', 'exam_attempts table exists');

-- 35. Test start_exam RPC existence
SELECT has_function('start_exam', ARRAY['uuid'], 'start_exam RPC exists');

-- 36. Test save_exam_answer RPC existence
SELECT has_function('save_exam_answer', ARRAY['uuid', 'uuid', 'uuid', 'text'], 'save_exam_answer RPC exists');

-- 37. Test submit_exam_attempt RPC existence
SELECT has_function('submit_exam_attempt', ARRAY['uuid'], 'submit_exam_attempt RPC exists');

-- 38. Test student_question_options view existence
SELECT has_view('student_question_options', 'student_question_options view exists');

-- 39. Test get_exam_attempt_bootstrap RPC existence
SELECT has_function('get_exam_attempt_bootstrap', ARRAY['uuid'], 'get_exam_attempt_bootstrap RPC exists');

-- 40. Test grade_exam_answer RPC existence
SELECT has_function('grade_exam_answer', ARRAY['uuid', 'numeric', 'text'], 'grade_exam_answer RPC exists');

-- 41. Test get_exam_result RPC existence
SELECT has_function('get_exam_result', ARRAY['uuid'], 'get_exam_result RPC exists');

-- 42. Answer-Key Non-Leak Test: Verify student_question_options view does NOT contain is_correct column
SELECT is(
    (SELECT COUNT(*)::int FROM information_schema.columns WHERE table_name = 'student_question_options' AND column_name = 'is_correct'),
    0,
    'student_question_options view does NOT contain is_correct column'
);

-- 43. Verify direct SELECT on question_options is revoked for authenticated users
SELECT is(
    (SELECT COUNT(*)::int FROM information_schema.role_table_grants WHERE table_name = 'question_options' AND grantee = 'authenticated' AND privilege_type = 'SELECT'),
    0,
    'Direct SELECT on question_options revoked for authenticated users'
);

-- 44. Test class_sessions table existence
SELECT has_table('class_sessions', 'class_sessions table exists');

-- 45. Test attendance_records table existence
SELECT has_table('attendance_records', 'attendance_records table exists');

-- 46. Test leave_requests table existence
SELECT has_table('leave_requests', 'leave_requests table exists');

-- 47. Test compensation_requests table existence
SELECT has_table('compensation_requests', 'compensation_requests table exists');

-- 48. Test mark_session_attendance RPC existence
SELECT has_function('mark_session_attendance', ARRAY['uuid', 'jsonb'], 'mark_session_attendance RPC exists');

-- 49. Test finalize_session_attendance RPC existence
SELECT has_function('finalize_session_attendance', ARRAY['uuid'], 'finalize_session_attendance RPC exists');

-- 50. Test review_leave_request RPC existence
SELECT has_function('review_leave_request', ARRAY['uuid', 'text', 'text'], 'review_leave_request RPC exists');

-- 51. Test get_session_roster RPC existence
SELECT has_function('get_session_roster', ARRAY['uuid'], 'get_session_roster RPC exists');

-- 52. Test generate_group_sessions RPC existence
SELECT has_function('generate_group_sessions', ARRAY['uuid', 'date', 'date'], 'generate_group_sessions RPC exists');

-- 53. Test assign_compensation_session RPC existence
SELECT has_function('assign_compensation_session', ARRAY['uuid', 'uuid'], 'assign_compensation_session RPC exists');

-- 54. Test get_student_attendance_summary RPC existence
SELECT has_function('get_student_attendance_summary', ARRAY['uuid'], 'get_student_attendance_summary RPC exists');

-- 55. Test current_teacher_assigned_to_group_on_date RPC existence
SELECT has_function('current_teacher_assigned_to_group_on_date', ARRAY['uuid', 'date'], 'current_teacher_assigned_to_group_on_date RPC exists');

-- 56. Test student_enrolled_in_group_on_date RPC existence
SELECT has_function('student_enrolled_in_group_on_date', ARRAY['uuid', 'uuid', 'date'], 'student_enrolled_in_group_on_date RPC exists');

-- 57. Test subscription_plans table existence
SELECT has_table('subscription_plans', 'subscription_plans table exists');

-- 58. Test student_subscriptions table existence
SELECT has_table('student_subscriptions', 'student_subscriptions table exists');

-- 59. Test subscription_installments table existence
SELECT has_table('subscription_installments', 'subscription_installments table exists');

-- 60. Test invoices table existence
SELECT has_table('invoices', 'invoices table exists');

-- 61. Test invoice_items table existence
SELECT has_table('invoice_items', 'invoice_items table exists');

-- 62. Test payment_attempts table existence
SELECT has_table('payment_attempts', 'payment_attempts table exists');

-- 63. Test payment_transactions table existence
SELECT has_table('payment_transactions', 'payment_transactions table exists');

-- 64. Test receipts table existence
SELECT has_table('receipts', 'receipts table exists');

-- 65. Test create_payment_intent RPC existence
SELECT has_function('create_payment_intent', ARRAY['uuid', 'text', 'text'], 'create_payment_intent RPC exists');

-- 66. Test apply_verified_payment RPC existence
SELECT has_function('apply_verified_payment', ARRAY['uuid', 'text', 'bigint', 'text'], 'apply_verified_payment RPC exists');

-- 67. Test record_manual_payment RPC existence
SELECT has_function('record_manual_payment', ARRAY['uuid', 'bigint', 'text', 'text', 'text'], 'record_manual_payment RPC exists');

-- 68. Test get_student_financial_summary RPC existence
SELECT has_function('get_student_financial_summary', ARRAY['uuid'], 'get_student_financial_summary RPC exists');

-- 69. PRIVILEGE DENIAL TEST: Verify EXECUTE on apply_verified_payment is REVOKED for authenticated role
SELECT is(
    (SELECT COUNT(*)::int FROM information_schema.routine_privileges WHERE routine_name = 'apply_verified_payment' AND grantee = 'authenticated' AND privilege_type = 'EXECUTE'),
    0,
    'EXECUTE privilege on apply_verified_payment is strictly REVOKED for authenticated users'
);

-- 70. Test payment_provider_events table existence
SELECT has_table('payment_provider_events', 'payment_provider_events audit table exists');

-- 71. Test unique_provider_transaction constraint presence
SELECT ok(
    EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_provider_transaction'),
    'unique_provider_transaction constraint exists on payment_transactions'
);

-- 72. Verify direct INSERT on payment_transactions is denied for authenticated role
SELECT is(
    (SELECT COUNT(*)::int FROM information_schema.table_privileges WHERE table_name = 'payment_transactions' AND grantee = 'authenticated' AND privilege_type = 'INSERT'),
    0,
    'Direct INSERT on payment_transactions is revoked for authenticated users'
);

-- 73. Verify direct INSERT on receipts is denied for authenticated role
SELECT is(
    (SELECT COUNT(*)::int FROM information_schema.table_privileges WHERE table_name = 'receipts' AND grantee = 'authenticated' AND privilege_type = 'INSERT'),
    0,
    'Direct INSERT on receipts is revoked for authenticated users'
);

-- 74. Test get_group_students RPC existence
SELECT has_function('get_group_students', ARRAY['uuid'], 'get_group_students RPC exists');

-- 75. Test create_homework_assignment RPC existence
SELECT has_function('create_homework_assignment', ARRAY['text', 'text', 'uuid', 'uuid', 'timestamp with time zone', 'numeric', 'text'], 'create_homework_assignment RPC exists');

-- 76. Test publish_homework RPC existence
SELECT has_function('publish_homework', ARRAY['uuid'], 'publish_homework RPC exists');

-- 77. Test grade_homework_submission RPC existence
SELECT has_function('grade_homework_submission', ARRAY['uuid', 'numeric', 'text'], 'grade_homework_submission RPC exists');

-- 78. Test create_exam_assignment RPC existence
SELECT has_function('create_exam_assignment', ARRAY['text', 'uuid', 'uuid', 'integer', 'numeric', 'numeric', 'text'], 'create_exam_assignment RPC exists');

SELECT * FROM finish();
ROLLBACK;
