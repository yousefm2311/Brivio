-- Migration: 20260807000020_communication_engine.sql
-- Description: Phase 9 Realtime Chat, Notifications & Announcements Engine

-- 1. Seed Phase 9 Granular Permissions
INSERT INTO public.permissions (id, code, module, action, description) VALUES
  ('10000000-0000-0000-0000-000000000017', 'chat.use', 'communication', 'use', 'Use internal direct and group messaging'),
  ('10000000-0000-0000-0000-000000000018', 'chat.create_group', 'communication', 'create_group', 'Create group conversations'),
  ('10000000-0000-0000-0000-000000000019', 'chat.moderate', 'communication', 'moderate', 'Moderate communication threads'),
  ('10000000-0000-0000-0000-000000000020', 'announcements.view', 'communication', 'view', 'View targeted internal announcements'),
  ('10000000-0000-0000-0000-000000000021', 'announcements.create', 'communication', 'create', 'Draft internal announcements'),
  ('10000000-0000-0000-0000-000000000022', 'announcements.update', 'communication', 'update', 'Edit internal announcements'),
  ('10000000-0000-0000-0000-000000000023', 'announcements.publish', 'communication', 'publish', 'Publish targeted internal announcements'),
  ('10000000-0000-0000-0000-000000000024', 'notifications.manage', 'communication', 'manage', 'Manage notification settings and triggers')
ON CONFLICT (code) DO NOTHING;

-- 2. Conversations Table
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_type TEXT NOT NULL CHECK (conversation_type IN ('direct', 'group')),
    title TEXT,
    academic_group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at TIMESTAMPTZ
);

-- 3. Conversation Members Table
CREATE TABLE IF NOT EXISTS public.conversation_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    member_role TEXT NOT NULL DEFAULT 'member' CHECK (member_role IN ('owner', 'admin', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    last_read_message_id UUID,
    last_read_at TIMESTAMPTZ,
    muted_until TIMESTAMPTZ,
    CONSTRAINT unique_active_conversation_member UNIQUE (conversation_id, user_id)
);

-- 4. Messages Table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'attachment', 'system')),
    text_content TEXT,
    reply_to_message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    edited_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

-- Foreign key check for last_read_message_id after messages table creation
ALTER TABLE public.conversation_members
    ADD CONSTRAINT fk_member_last_read_message
    FOREIGN KEY (last_read_message_id) REFERENCES public.messages(id) ON DELETE SET NULL;

-- 5. Message Attachments Table
CREATE TABLE IF NOT EXISTS public.message_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    original_name TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size_bytes BIGINT NOT NULL CHECK (size_bytes > 0),
    uploaded_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    read_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Notification Preferences Table
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    in_app_enabled BOOLEAN NOT NULL DEFAULT true,
    email_enabled BOOLEAN NOT NULL DEFAULT false,
    push_enabled BOOLEAN NOT NULL DEFAULT false,
    categories JSONB NOT NULL DEFAULT '{"chat": true, "announcements": true, "academic": true, "payments": true}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Announcements Table
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'published', 'archived')),
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'important', 'urgent')),
    publish_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    requires_acknowledgement BOOLEAN NOT NULL DEFAULT false,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Announcement Targets Table
CREATE TABLE IF NOT EXISTS public.announcement_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    announcement_id UUID NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('all', 'branch', 'role', 'academic_group', 'user')),
    target_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. Announcement Reads & Acknowledgements Table
CREATE TABLE IF NOT EXISTS public.announcement_reads (
    announcement_id UUID NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    PRIMARY KEY (announcement_id, user_id)
);

-- 11. Storage Bucket for Private Chat Attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat_attachments', 'chat_attachments', false)
ON CONFLICT (id) DO NOTHING;

-- 12. Enable Row Level Security
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;

-- 13. RLS Security Policies

-- Conversations Policy: Viewable by active members or admins
CREATE POLICY "Conversations viewable by active members or admin"
ON public.conversations FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    EXISTS (
        SELECT 1 FROM public.conversation_members cm
        WHERE cm.conversation_id = conversations.id
          AND cm.user_id = auth.uid()
          AND cm.left_at IS NULL
    )
);

-- Conversation Members Policy: Viewable by co-members
CREATE POLICY "Conversation members viewable by conversation participants"
ON public.conversation_members FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    EXISTS (
        SELECT 1 FROM public.conversation_members cm
        WHERE cm.conversation_id = conversation_members.conversation_id
          AND cm.user_id = auth.uid()
          AND cm.left_at IS NULL
    )
);

-- Messages Policy: Viewable by active conversation members
CREATE POLICY "Messages viewable by active conversation members"
ON public.messages FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    EXISTS (
        SELECT 1 FROM public.conversation_members cm
        WHERE cm.conversation_id = messages.conversation_id
          AND cm.user_id = auth.uid()
          AND cm.left_at IS NULL
    )
);

-- Message Attachments Policy: Viewable by active conversation members
CREATE POLICY "Attachments viewable by active conversation members"
ON public.message_attachments FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.conversation_members cm ON cm.conversation_id = m.conversation_id
        WHERE m.id = message_attachments.message_id
          AND cm.user_id = auth.uid()
          AND cm.left_at IS NULL
    )
);

-- Notifications Policy: User-scoped
CREATE POLICY "Notifications viewable and manageable by owner"
ON public.notifications FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Notification Preferences Policy: User-scoped
CREATE POLICY "Notification preferences viewable and manageable by owner"
ON public.notification_preferences FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Announcements Policy: Viewable if published & targeted to user
CREATE POLICY "Announcements viewable by targeted audience or admin"
ON public.announcements FOR SELECT TO authenticated
USING (
    public.is_admin_or_super() OR
    public.has_permission('announcements.publish') OR
    (
        status = 'published' AND
        publish_at <= NOW() AND
        (expires_at IS NULL OR expires_at > NOW()) AND
        EXISTS (
            SELECT 1 FROM public.announcement_targets at
            WHERE at.announcement_id = announcements.id AND (
                at.target_type = 'all' OR
                (at.target_type = 'role' AND at.target_id = public.current_user_role()::text) OR
                (at.target_type = 'user' AND at.target_id = auth.uid()::text) OR
                (at.target_type = 'branch' AND at.target_id = (SELECT branch_id::text FROM public.profiles WHERE id = auth.uid()))
            )
        )
    )
);

-- Announcement Targets Policy: Viewable by authenticated
CREATE POLICY "Announcement targets viewable by authenticated users"
ON public.announcement_targets FOR SELECT TO authenticated USING (true);

-- Announcement Reads Policy: Viewable and manageable by owner
CREATE POLICY "Announcement reads manageable by user"
ON public.announcement_reads FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 14. Server-Authoritative RPCs

-- Atomic Get or Create Direct Conversation RPC
CREATE OR REPLACE FUNCTION public.get_or_create_direct_conversation(p_other_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    curr_user UUID := auth.uid();
    conv_id UUID;
    other_exists BOOLEAN;
BEGIN
    IF curr_user IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
    END IF;

    IF curr_user = p_other_user_id THEN
        RAISE EXCEPTION 'Cannot create direct conversation with yourself' USING ERRCODE = '22000';
    END IF;

    SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id = p_other_user_id) INTO other_exists;
    IF NOT other_exists THEN
        RAISE EXCEPTION 'Target user not found' USING ERRCODE = '44000';
    END IF;

    SELECT c.id INTO conv_id
    FROM public.conversations c
    JOIN public.conversation_members cm1 ON cm1.conversation_id = c.id AND cm1.user_id = curr_user AND cm1.left_at IS NULL
    JOIN public.conversation_members cm2 ON cm2.conversation_id = c.id AND cm2.user_id = p_other_user_id AND cm2.left_at IS NULL
    WHERE c.conversation_type = 'direct'
    LIMIT 1;

    IF conv_id IS NULL THEN
        INSERT INTO public.conversations (conversation_type, created_by)
        VALUES ('direct', curr_user)
        RETURNING id INTO conv_id;

        INSERT INTO public.conversation_members (conversation_id, user_id, member_role)
        VALUES
            (conv_id, curr_user, 'owner'),
            (conv_id, p_other_user_id, 'member');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'conversation_id', conv_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Send Message RPC
CREATE OR REPLACE FUNCTION public.send_message(
    p_conversation_id UUID,
    p_text TEXT,
    p_reply_to_message_id UUID DEFAULT NULL,
    p_message_type TEXT DEFAULT 'text'
)
RETURNS JSONB AS $$
DECLARE
    curr_user UUID := auth.uid();
    is_member BOOLEAN;
    msg_id UUID;
    reply_valid BOOLEAN;
    clean_text TEXT;
BEGIN
    IF curr_user IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.conversation_members
        WHERE conversation_id = p_conversation_id AND user_id = curr_user AND left_at IS NULL
    ) INTO is_member;

    IF NOT is_member AND NOT public.is_admin_or_super() THEN
        RAISE EXCEPTION 'Unauthorized: Not an active member of this conversation' USING ERRCODE = '42501';
    END IF;

    clean_text := TRIM(p_text);
    IF (clean_text IS NULL OR clean_text = '') AND p_message_type = 'text' THEN
        RAISE EXCEPTION 'Message text content cannot be empty' USING ERRCODE = '22023';
    END IF;

    IF p_reply_to_message_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.messages
            WHERE id = p_reply_to_message_id AND conversation_id = p_conversation_id
        ) INTO reply_valid;
        IF NOT reply_valid THEN
            RAISE EXCEPTION 'Reply target message does not exist in this conversation' USING ERRCODE = '22000';
        END IF;
    END IF;

    INSERT INTO public.messages (conversation_id, sender_id, message_type, text_content, reply_to_message_id, sent_at)
    VALUES (p_conversation_id, curr_user, p_message_type, clean_text, p_reply_to_message_id, NOW())
    RETURNING id INTO msg_id;

    UPDATE public.conversations SET last_message_at = NOW(), updated_at = NOW() WHERE id = p_conversation_id;

    RETURN jsonb_build_object(
        'success', true,
        'message_id', msg_id,
        'conversation_id', p_conversation_id,
        'sender_id', curr_user,
        'sent_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Mark Conversation Read RPC
CREATE OR REPLACE FUNCTION public.mark_conversation_read(
    p_conversation_id UUID,
    p_message_id UUID
)
RETURNS JSONB AS $$
DECLARE
    curr_user UUID := auth.uid();
    msg_belongs BOOLEAN;
BEGIN
    IF curr_user IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.messages WHERE id = p_message_id AND conversation_id = p_conversation_id
    ) INTO msg_belongs;

    IF NOT msg_belongs THEN
        RAISE EXCEPTION 'Message does not belong to conversation' USING ERRCODE = '22000';
    END IF;

    UPDATE public.conversation_members
    SET last_read_message_id = p_message_id,
        last_read_at = NOW()
    WHERE conversation_id = p_conversation_id AND user_id = curr_user AND left_at IS NULL;

    RETURN jsonb_build_object('success', true, 'conversation_id', p_conversation_id, 'last_read_message_id', p_message_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Get Conversation Unread Count RPC
CREATE OR REPLACE FUNCTION public.get_conversation_unread_count(p_conversation_id UUID)
RETURNS INT AS $$
DECLARE
    curr_user UUID := auth.uid();
    mem RECORD;
    cnt INT := 0;
BEGIN
    IF curr_user IS NULL THEN RETURN 0; END IF;

    SELECT * INTO mem FROM public.conversation_members
    WHERE conversation_id = p_conversation_id AND user_id = curr_user AND left_at IS NULL;

    IF mem.id IS NULL THEN RETURN 0; END IF;

    IF mem.last_read_at IS NULL THEN
        SELECT COUNT(*)::int INTO cnt FROM public.messages
        WHERE conversation_id = p_conversation_id AND sender_id != curr_user AND deleted_at IS NULL;
    ELSE
        SELECT COUNT(*)::int INTO cnt FROM public.messages
        WHERE conversation_id = p_conversation_id AND sender_id != curr_user AND sent_at > mem.last_read_at AND deleted_at IS NULL;
    END IF;

    RETURN cnt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Get User Total Unread Conversations Count RPC
CREATE OR REPLACE FUNCTION public.get_user_unread_conversations_total()
RETURNS INT AS $$
DECLARE
    curr_user UUID := auth.uid();
    tot INT := 0;
BEGIN
    IF curr_user IS NULL THEN RETURN 0; END IF;

    SELECT COUNT(DISTINCT m.conversation_id)::int INTO tot
    FROM public.messages m
    JOIN public.conversation_members cm ON cm.conversation_id = m.conversation_id AND cm.user_id = curr_user AND cm.left_at IS NULL
    WHERE m.sender_id != curr_user
      AND m.deleted_at IS NULL
      AND (cm.last_read_at IS NULL OR m.sent_at > cm.last_read_at);

    RETURN tot;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Publish Announcement RPC
CREATE OR REPLACE FUNCTION public.publish_announcement(p_announcement_id UUID)
RETURNS JSONB AS $$
BEGIN
    IF NOT (public.is_admin_or_super() OR public.has_permission('announcements.publish')) THEN
        RAISE EXCEPTION 'Unauthorized to publish announcements' USING ERRCODE = '42501';
    END IF;

    UPDATE public.announcements
    SET status = 'published',
        publish_at = NOW(),
        updated_at = NOW()
    WHERE id = p_announcement_id;

    RETURN jsonb_build_object('success', true, 'announcement_id', p_announcement_id, 'status', 'published');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Acknowledge Announcement RPC
CREATE OR REPLACE FUNCTION public.acknowledge_announcement(p_announcement_id UUID)
RETURNS JSONB AS $$
DECLARE
    curr_user UUID := auth.uid();
BEGIN
    IF curr_user IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.announcement_reads (announcement_id, user_id, read_at, acknowledged_at)
    VALUES (p_announcement_id, curr_user, NOW(), NOW())
    ON CONFLICT (announcement_id, user_id)
    DO UPDATE SET acknowledged_at = NOW(), read_at = COALESCE(announcement_reads.read_at, NOW());

    RETURN jsonb_build_object('success', true, 'announcement_id', p_announcement_id, 'acknowledged', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Mark Notification Read RPC
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id UUID)
RETURNS JSONB AS $$
DECLARE
    curr_user UUID := auth.uid();
BEGIN
    IF curr_user IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
    END IF;

    UPDATE public.notifications
    SET read_at = NOW()
    WHERE id = p_notification_id AND user_id = curr_user;

    RETURN jsonb_build_object('success', true, 'notification_id', p_notification_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Mark All Notifications Read RPC
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS JSONB AS $$
DECLARE
    curr_user UUID := auth.uid();
BEGIN
    IF curr_user IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
    END IF;

    UPDATE public.notifications
    SET read_at = NOW()
    WHERE user_id = curr_user AND read_at IS NULL;

    RETURN jsonb_build_object('success', true, 'user_id', curr_user);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 15. Grant Function Execution Permissions
REVOKE EXECUTE ON FUNCTION public.get_or_create_direct_conversation(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_or_create_direct_conversation(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.send_message(UUID, TEXT, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_message(UUID, TEXT, UUID, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_conversation_read(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_conversation_read(UUID, UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_conversation_unread_count(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_conversation_unread_count(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_user_unread_conversations_total() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_unread_conversations_total() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.publish_announcement(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_announcement(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.acknowledge_announcement(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.acknowledge_announcement(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_notification_read(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_all_notifications_read() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;

-- 16. Schema Table Grants (After Table Creation)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role, postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role, postgres;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role, postgres;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated, anon;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;
REVOKE SELECT ON public.question_options FROM authenticated, anon;
