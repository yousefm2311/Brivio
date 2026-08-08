-- Supabase Development Seed Data (supabase/seed.sql)

-- 1. Seed Canonical Roles
INSERT INTO public.roles (id, name, description) VALUES
  ('00000000-0000-0000-0000-000000000001', 'super_admin', 'Global System Controller'),
  ('00000000-0000-0000-0000-000000000002', 'admin', 'Branch Administrator'),
  ('00000000-0000-0000-0000-000000000003', 'staff', 'Operations Staff'),
  ('00000000-0000-0000-0000-000000000004', 'teacher', 'Educator'),
  ('00000000-0000-0000-0000-000000000005', 'parent', 'Guardian'),
  ('00000000-0000-0000-0000-000000000006', 'student', 'Learner')
ON CONFLICT (name) DO NOTHING;

-- 2. Seed Granular Permissions
INSERT INTO public.permissions (id, code, module, action, description) VALUES
  ('10000000-0000-0000-0000-000000000001', 'students.view', 'students', 'view', 'View student profiles and details'),
  ('10000000-0000-0000-0000-000000000002', 'students.create', 'students', 'create', 'Create student profiles'),
  ('10000000-0000-0000-0000-000000000003', 'students.update', 'students', 'update', 'Update student profiles'),
  ('10000000-0000-0000-0000-000000000004', 'students.delete', 'students', 'delete', 'Archive student profiles'),
  ('10000000-0000-0000-0000-000000000005', 'parents.view', 'parents', 'view', 'View parent profiles'),
  ('10000000-0000-0000-0000-000000000006', 'groups.view', 'groups', 'view', 'View groups and schedules'),
  ('10000000-0000-0000-0000-000000000007', 'groups.create', 'groups', 'create', 'Create groups'),
  ('10000000-0000-0000-0000-000000000008', 'enrollments.view', 'enrollments', 'view', 'View enrollments'),
  ('10000000-0000-0000-0000-000000000009', 'curriculum.view', 'curriculum', 'view', 'View units and lessons'),
  ('10000000-0000-0000-0000-000000000010', 'curriculum.publish', 'curriculum', 'publish', 'Publish units and lessons'),
  ('10000000-0000-0000-0000-000000000011', 'questions.view', 'assessment', 'view', 'View question bank'),
  ('10000000-0000-0000-0000-000000000012', 'exams.publish', 'assessment', 'publish', 'Publish exams'),
  ('10000000-0000-0000-0000-000000000013', 'attendance.mark', 'attendance', 'mark', 'Mark session attendance'),
  ('10000000-0000-0000-0000-000000000014', 'leave.review', 'attendance', 'review', 'Review leave requests'),
  ('10000000-0000-0000-0000-000000000015', 'invoices.view', 'payments', 'view', 'View invoices'),
  ('10000000-0000-0000-0000-000000000016', 'payments.collect', 'payments', 'collect', 'Collect manual cash payments')
ON CONFLICT (code) DO NOTHING;

-- 3. Seed Branches
INSERT INTO public.branches (id, name, code, address, phone_number, status) VALUES
  ('20000000-0000-0000-0000-000000000001', 'Main Campus', 'CAMPUS-MAIN', '100 Academy Blvd', '+15550199', 'active'),
  ('20000000-0000-0000-0000-000000000002', 'North Branch', 'CAMPUS-NORTH', '200 North Ave', '+15550299', 'active')
ON CONFLICT (code) DO NOTHING;

-- 4. Seed Development Auth Users & Profiles for All Roles
-- Standard password for all development test accounts: Password123!
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  confirmation_token, recovery_token, email_change_token_new, reauthentication_token, email_change,
  raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at
) VALUES
  ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'superadmin@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"full_name":"Super Admin User"}', false, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"full_name":"Branch Admin User"}', false, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"full_name":"Operations Staff User"}', false, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'teacher@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"full_name":"Educator Teacher User"}', false, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'parent@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"full_name":"Guardian Parent User"}', false, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000106', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'student@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"full_name":"Learner Student User"}', false, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Seed auth.identities (provider_id = email for email provider)س
INSERT INTO auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at) VALUES
  ('00000000-0000-0000-0000-000000000101', 'superadmin@academy.com', '00000000-0000-0000-0000-000000000101', '{"sub":"00000000-0000-0000-0000-000000000101","email":"superadmin@academy.com"}', 'email', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000102', 'admin@academy.com', '00000000-0000-0000-0000-000000000102', '{"sub":"00000000-0000-0000-0000-000000000102","email":"admin@academy.com"}', 'email', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000103', 'staff@academy.com', '00000000-0000-0000-0000-000000000103', '{"sub":"00000000-0000-0000-0000-000000000103","email":"staff@academy.com"}', 'email', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000104', 'teacher@academy.com', '00000000-0000-0000-0000-000000000104', '{"sub":"00000000-0000-0000-0000-000000000104","email":"teacher@academy.com"}', 'email', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000105', 'parent@academy.com', '00000000-0000-0000-0000-000000000105', '{"sub":"00000000-0000-0000-0000-000000000105","email":"parent@academy.com"}', 'email', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000106', 'student@academy.com', '00000000-0000-0000-0000-000000000106', '{"sub":"00000000-0000-0000-0000-000000000106","email":"student@academy.com"}', 'email', NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Seed Public Profiles
INSERT INTO public.profiles (id, email, full_name, role, branch_id, status) VALUES
  ('00000000-0000-0000-0000-000000000101', 'superadmin@academy.com', 'Super Admin User', 'super_admin', '20000000-0000-0000-0000-000000000001', 'active'),
  ('00000000-0000-0000-0000-000000000102', 'admin@academy.com', 'Branch Admin User', 'admin', '20000000-0000-0000-0000-000000000001', 'active'),
  ('00000000-0000-0000-0000-000000000103', 'staff@academy.com', 'Operations Staff User', 'staff', '20000000-0000-0000-0000-000000000001', 'active'),
  ('00000000-0000-0000-0000-000000000104', 'teacher@academy.com', 'Educator Teacher User', 'teacher', '20000000-0000-0000-0000-000000000001', 'active'),
  ('00000000-0000-0000-0000-000000000105', 'parent@academy.com', 'Guardian Parent User', 'parent', '20000000-0000-0000-0000-000000000001', 'active'),
  ('00000000-0000-0000-0000-000000000106', 'student@academy.com', 'Learner Student User', 'student', '20000000-0000-0000-0000-000000000001', 'active')
ON CONFLICT (id) DO UPDATE SET
  role = EXCLUDED.role,
  full_name = EXCLUDED.full_name,
  branch_id = EXCLUDED.branch_id,
  status = EXCLUDED.status;

-- Seed Domain Entity Tables (Students, Parents, Teachers)
INSERT INTO public.teachers (id, profile_id, primary_branch_id, specialization) VALUES
  ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000104', '20000000-0000-0000-0000-000000000001', 'Computer Science')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.parents (id, profile_id) VALUES
  ('80000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000105')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.students (id, profile_id, student_code, primary_branch_id) VALUES
  ('90000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000106', 'STU-2026-0001', '20000000-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- Parent-Student Link
INSERT INTO public.parent_students (parent_id, student_id, relationship_type, is_primary) VALUES
  ('80000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001', 'guardian', true)
ON CONFLICT (parent_id, student_id) DO NOTHING;

-- 5. Seed Subjects Catalog
INSERT INTO public.subjects (id, name, code, description, bucket, object_path, status) VALUES
  ('30000000-0000-0000-0000-000000000001', 'Computer Science 101', 'CS-101', 'Introduction to Algorithms, Python, and Data Structures', 'curriculum_assets', 'cs101/cover.png', 'active'),
  ('30000000-0000-0000-0000-000000000002', 'Advanced Physics', 'PHYS-201', 'Classical Mechanics & Electromagnetism', 'curriculum_assets', 'phys201/cover.png', 'active')
ON CONFLICT (code) DO NOTHING;

-- 6. Seed Semesters
INSERT INTO public.semesters (id, subject_id, name, code, order_number, start_date, end_date, status) VALUES
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Fall 2026', 'FALL-2026', 1, '2026-09-01', '2026-12-31', 'active')
ON CONFLICT (code) DO NOTHING;

-- 7. Seed Units
INSERT INTO public.units (id, semester_id, name, code, order_number, status) VALUES
  ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'Unit 1: Introduction to Algorithms', 'U1-ALG', 1, 'active')
ON CONFLICT (id) DO NOTHING;

-- 8. Seed Lessons
INSERT INTO public.lessons (id, unit_id, title, lesson_type, order_number, status, published_at, estimated_duration_minutes) VALUES
  ('60000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '1.1 Video: What is an Algorithm?', 'video', 1, 'published', NOW(), 15)
ON CONFLICT (id) DO NOTHING;

-- 9. Seed Groups
INSERT INTO public.groups (id, name, code, subject_id, branch_id, capacity, status) VALUES
  ('c1000000-0000-0000-0000-000000000001', 'CS Group A', 'GRP-CSA', '30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 20, 'active'),
  ('c1000000-0000-0000-0000-000000000002', 'Physics Group B', 'GRP-PHYSB', '30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 15, 'active')
ON CONFLICT (code) DO NOTHING;

-- 10. Seed Class Sessions
INSERT INTO public.class_sessions (id, group_id, session_date, scheduled_start_at, scheduled_end_at, status, location) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', CURRENT_DATE, NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour', 'in_progress', 'Room 101')
ON CONFLICT (id) DO NOTHING;

-- 11. Seed Subscription Plans
INSERT INTO public.subscription_plans (id, name, description, billing_type, total_amount_minor, currency, installment_count, status) VALUES
  ('b0000000-0000-0000-0000-000000000001', 'Full Semester CS 101 Tuition', 'Complete CS 101 Tuition for Fall 2026', 'installment', 300000, 'EGP', 3, 'active'),
  ('b0000000-0000-0000-0000-000000000002', 'Physics 201 Single Term Plan', 'Physics 201 Single Term Package', 'one_time', 150000, 'EGP', 1, 'active')
ON CONFLICT (id) DO NOTHING;

-- 12. Seed Phase 9 Conversations
INSERT INTO public.conversations (id, conversation_type, title, academic_group_id, created_by, created_at, updated_at, last_message_at) VALUES
  ('e2000000-0000-0000-0000-000000000001', 'direct', NULL, NULL, '00000000-0000-0000-0000-000000000104', NOW() - INTERVAL '1 day', NOW(), NOW()),
  ('e2000000-0000-0000-0000-000000000002', 'group', 'CS Group A Discussion', 'c1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000104', NOW() - INTERVAL '2 days', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- 13. Seed Conversation Members
INSERT INTO public.conversation_members (id, conversation_id, user_id, member_role, joined_at) VALUES
  ('e3000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000104', 'owner', NOW() - INTERVAL '1 day'),
  ('e3000000-0000-0000-0000-000000000002', 'e2000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000106', 'member', NOW() - INTERVAL '1 day'),
  ('e3000000-0000-0000-0000-000000000003', 'e2000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000104', 'owner', NOW() - INTERVAL '2 days'),
  ('e3000000-0000-0000-0000-000000000004', 'e2000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000106', 'member', NOW() - INTERVAL '2 days')
ON CONFLICT (id) DO NOTHING;

-- 14. Seed Messages
INSERT INTO public.messages (id, conversation_id, sender_id, message_type, text_content, sent_at) VALUES
  ('e4000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000104', 'text', 'Welcome to CS 101! Please check the syllabus.', NOW() - INTERVAL '2 hours'),
  ('e4000000-0000-0000-0000-000000000002', 'e2000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000106', 'text', 'Thank you Teacher! I have reviewed Unit 1.', NOW() - INTERVAL '1 hour')
ON CONFLICT (id) DO NOTHING;

-- 15. Seed In-App Notifications
INSERT INTO public.notifications (id, user_id, notification_type, title, body, data, created_at) VALUES
  ('e5000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000106', 'chat_message', 'New Message from Teacher', 'Welcome to CS 101! Please check the syllabus.', '{"conversation_id": "e2000000-0000-0000-0000-000000000001"}'::jsonb, NOW() - INTERVAL '2 hours')
ON CONFLICT (id) DO NOTHING;

-- 16. Seed Announcements & Targets
INSERT INTO public.announcements (id, title, body, status, priority, publish_at, requires_acknowledgement, created_by, created_at) VALUES
  ('e6000000-0000-0000-0000-000000000001', 'Welcome to Fall 2026 Academic Term', 'We are excited to launch the new term across all branches.', 'published', 'normal', NOW() - INTERVAL '3 days', false, '00000000-0000-0000-0000-000000000101', NOW() - INTERVAL '3 days'),
  ('e6000000-0000-0000-0000-000000000002', 'Important Safety Policy Acknowledgement', 'All learners must acknowledge the updated lab safety guidelines.', 'published', 'urgent', NOW() - INTERVAL '1 day', true, '00000000-0000-0000-0000-000000000101', NOW() - INTERVAL '1 day'),
  ('e6000000-0000-0000-0000-000000000003', 'Draft Campus Renovation Announcement', 'Draft announcement regarding Main Campus upgrades.', 'draft', 'normal', NOW() + INTERVAL '5 days', false, '00000000-0000-0000-0000-000000000101', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.announcement_targets (id, announcement_id, target_type, target_id) VALUES
  ('e7000000-0000-0000-0000-000000000001', 'e6000000-0000-0000-0000-000000000001', 'all', NULL),
  ('e7000000-0000-0000-0000-000000000002', 'e6000000-0000-0000-0000-000000000002', 'role', 'student'),
  ('e7000000-0000-0000-0000-000000000003', 'e6000000-0000-0000-0000-000000000003', 'all', NULL)
ON CONFLICT (id) DO NOTHING;

