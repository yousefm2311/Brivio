INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at
) VALUES
  ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'superadmin@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Super Admin User"}', false, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Branch Admin User"}', false, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Operations Staff User"}', false, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'teacher@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Educator Teacher User"}', false, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'parent@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Guardian Parent User"}', false, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000106', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'student@academy.com', crypt('Password123!', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Learner Student User"}', false, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Seed auth.identities
INSERT INTO auth.identities (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at) VALUES
  ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000101', '{"sub":"00000000-0000-0000-0000-000000000101","email":"superadmin@academy.com"}', 'email', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000102', '{"sub":"00000000-0000-0000-0000-000000000102","email":"admin@academy.com"}', 'email', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000103', '{"sub":"00000000-0000-0000-0000-000000000103","email":"staff@academy.com"}', 'email', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000104', '{"sub":"00000000-0000-0000-0000-000000000104","email":"teacher@academy.com"}', 'email', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000105', '{"sub":"00000000-0000-0000-0000-000000000105","email":"parent@academy.com"}', 'email', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000106', '00000000-0000-0000-0000-000000000106', '{"sub":"00000000-0000-0000-0000-000000000106","email":"student@academy.com"}', 'email', NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Seed Public Profiles
INSERT INTO public.profiles (id, email, full_name, role, branch_id, status) VALUES
  ('00000000-0000-0000-0000-000000000101', 'superadmin@academy.com', 'Super Admin User', 'super_admin', '20000000-0000-0000-0000-000000000001', 'active'),
  ('00000000-0000-0000-0000-000000000102', 'admin@academy.com', 'Branch Admin User', 'admin', '20000000-0000-0000-0000-000000000001', 'active'),
  ('00000000-0000-0000-0000-000000000103', 'staff@academy.com', 'Operations Staff User', 'staff', '20000000-0000-0000-0000-000000000001', 'active'),
  ('00000000-0000-0000-0000-000000000104', 'teacher@academy.com', 'Educator Teacher User', 'teacher', '20000000-0000-0000-0000-000000000001', 'active'),
  ('00000000-0000-0000-0000-000000000105', 'parent@academy.com', 'Guardian Parent User', 'parent', '20000000-0000-0000-0000-000000000001', 'active'),
  ('00000000-0000-0000-0000-000000000106', 'student@academy.com', 'Learner Student User', 'student', '20000000-0000-0000-0000-000000000001', 'active')
ON CONFLICT (id) DO NOTHING;
