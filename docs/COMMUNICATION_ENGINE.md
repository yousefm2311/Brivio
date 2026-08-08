# Phase 9: Realtime Chat, Notifications & Announcements Engine Documentation

## 1. Architecture Overview
The Communication Engine provides real-time messaging, scalable read receipts, private attachments, user-scoped in-app notifications, and targeted announcements. It is built on PostgreSQL RLS, Supabase Realtime, Supabase Storage (`chat_attachments`), and server-authoritative RPCs.

## 2. Conversation & Messaging Model
- **Conversation Types**: `direct` (one-on-one DM) and `group` (academic or staff group chat).
- **Direct DM Uniqueness**: Atomic `get_or_create_direct_conversation(p_other_user_id)` RPC prevents duplicate threads between the same two users.
- **Server-Authoritative Sender & Timestamp**: `send_message(p_conversation_id, p_text, p_reply_to_message_id, p_message_type)` RPC derives `sender_id` directly from `auth.uid()` and assigns server-side `sent_at = NOW()`.
- **Soft Deletion & Editing**: Message editing updates `edited_at` timestamp. Soft deletion sets `deleted_at`, preserving audit integrity while displaying "This message was deleted" to thread members.

## 3. Read Receipts & Scalable Unread Counting
- **Forward-Only Pointer**: `mark_conversation_read(p_conversation_id, p_message_id)` updates `last_read_message_id` and `last_read_at` on `conversation_members`.
- **Server-Side Counting**: `get_conversation_unread_count` and `get_user_unread_conversations_total` derive exact unread counts without fetching full message histories to Flutter.

## 4. Private Attachment Security
- Private Supabase Storage bucket `chat_attachments` enforces RLS policies. Objects can only be retrieved via signed URLs generated for active conversation members (`left_at IS NULL`).

## 5. In-App Notifications & Targeted Announcements
- **Notifications**: User-scoped inbox backed by `notifications` table (`user_id = auth.uid()`). Supports `mark_notification_read` and `mark_all_notifications_read`.
- **Targeted Announcements**: `announcements` and `announcement_targets` support targeting by `all`, `role`, `branch`, `academic_group`, or `user`. Published announcements are viewable only after `publish_at <= NOW()`.
- **Read & Acknowledgement Tracking**: Urgent announcements record formal user acknowledgement via `acknowledge_announcement(p_announcement_id)`.

## 6. Multi-Account Isolation & Logout
- Repositories (`SupabaseConversationRepository`, `SupabaseMessageRepository`, `SupabaseNotificationRepository`, `SupabaseAnnouncementRepository`) implement `clearCache()` to unsubscribe from Realtime channels and purge local state when users log out.
