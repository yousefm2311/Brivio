BEGIN;
SELECT plan(20);

-- 1. Table Existence Checks
SELECT has_table('conversations', 'conversations table exists');
SELECT has_table('conversation_members', 'conversation_members table exists');
SELECT has_table('messages', 'messages table exists');
SELECT has_table('message_attachments', 'message_attachments table exists');
SELECT has_table('notifications', 'notifications table exists');
SELECT has_table('announcements', 'announcements table exists');
SELECT has_table('announcement_targets', 'announcement_targets table exists');
SELECT has_table('announcement_reads', 'announcement_reads table exists');

-- 2. Row Level Security Enabled Checks
SELECT table_privs_are('public', 'conversations', 'service_role', ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'], 'service_role has full access to conversations');
SELECT table_privs_are('public', 'messages', 'service_role', ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'], 'service_role has full access to messages');

-- 3. Function Signatures & Grants
SELECT has_function('get_or_create_direct_conversation', ARRAY['uuid'], 'get_or_create_direct_conversation RPC exists');
SELECT has_function('send_message', ARRAY['uuid', 'text', 'uuid', 'text'], 'send_message RPC exists');
SELECT has_function('mark_conversation_read', ARRAY['uuid', 'uuid'], 'mark_conversation_read RPC exists');
SELECT has_function('get_conversation_unread_count', ARRAY['uuid'], 'get_conversation_unread_count RPC exists');
SELECT has_function('get_user_unread_conversations_total', 'get_user_unread_conversations_total RPC exists');
SELECT has_function('publish_announcement', ARRAY['uuid'], 'publish_announcement RPC exists');
SELECT has_function('acknowledge_announcement', ARRAY['uuid'], 'acknowledge_announcement RPC exists');
SELECT has_function('mark_notification_read', ARRAY['uuid'], 'mark_notification_read RPC exists');
SELECT has_function('mark_all_notifications_read', 'mark_all_notifications_read RPC exists');

-- 4. Seed Integrity Checks
SELECT is(
    (SELECT COUNT(*)::int FROM public.conversations),
    2,
    'Seeded conversations count equals 2'
);

SELECT * FROM finish();
ROLLBACK;
