-- Migration: 20260810000002_fix_question_options_grant.sql
-- Description: Restore SELECT privilege on question_options to authenticated users to allow Flutter app to fetch exams and homework correctly.

GRANT SELECT ON public.question_options TO authenticated;
