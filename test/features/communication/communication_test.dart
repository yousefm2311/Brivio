import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/communication/domain/models/announcement.dart';
import 'package:flutter_application_1/features/communication/domain/models/conversation.dart';
import 'package:flutter_application_1/features/communication/domain/models/message.dart';
import 'package:flutter_application_1/features/communication/domain/models/notification.dart';
import 'package:flutter_application_1/features/communication/domain/repositories/i_announcement_repository.dart';
import 'package:flutter_application_1/features/communication/domain/repositories/i_conversation_repository.dart';
import 'package:flutter_application_1/features/communication/domain/repositories/i_notification_repository.dart';
import 'package:flutter_application_1/features/communication/presentation/viewmodels/announcement_viewmodel.dart';
import 'package:flutter_application_1/features/communication/presentation/viewmodels/conversation_list_viewmodel.dart';
import 'package:flutter_application_1/features/communication/presentation/viewmodels/notification_center_viewmodel.dart';
import 'package:flutter_application_1/features/communication/presentation/screens/conversation_list_screen.dart';
import 'package:flutter_application_1/features/communication/presentation/screens/notification_center_screen.dart';
import 'package:flutter_application_1/features/communication/presentation/screens/announcement_center_screen.dart';

class MockConversationRepository implements IConversationRepository {
  List<Conversation> mockConversations = [
    Conversation(
      id: 'e2000000-0000-0000-0000-000000000001',
      conversationType: ConversationType.direct,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
      lastMessageText: 'Welcome to CS 101!',
      unreadCount: 2,
      members: [
        ConversationMember(
          id: 'e3000000-0000-0000-0000-000000000001',
          conversationId: 'e2000000-0000-0000-0000-000000000001',
          userId: '00000000-0000-0000-0000-000000000104',
          joinedAt: DateTime.now(),
          userFullName: 'Dr. Alan Turing',
        ),
      ],
    ),
  ];

  @override
  Future<List<Conversation>> getConversations() async => mockConversations;

  @override
  Future<String> getOrCreateDirectConversation(String otherUserId) async =>
      'e2000000-0000-0000-0000-000000000001';

  @override
  Future<Conversation?> getConversationById(String conversationId) async =>
      mockConversations.first;

  @override
  Future<void> markConversationRead(
    String conversationId,
    String messageId,
  ) async {}

  @override
  Future<int> getConversationUnreadCount(String conversationId) async => 0;

  @override
  Future<int> getUserUnreadConversationsTotal() async => 2;

  @override
  Stream<void> subscribeToConversationListUpdates() => const Stream.empty();

  @override
  void clearCache() {}
}

class MockNotificationRepository implements INotificationRepository {
  List<AppNotification> mockNotifications = [
    AppNotification(
      id: 'e5000000-0000-0000-0000-000000000001',
      userId: '00000000-0000-0000-0000-000000000106',
      notificationType: 'chat_message',
      title: 'New Message from Teacher',
      body: 'Welcome to CS 101!',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<AppNotification>> getNotifications() async => mockNotifications;

  @override
  Future<int> getUnreadCount() async => 1;

  @override
  Future<void> markRead(String notificationId) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<NotificationPreference> getPreferences() async =>
      NotificationPreference(
        userId: '00000000-0000-0000-0000-000000000106',
        updatedAt: DateTime.now(),
      );

  @override
  Future<void> updatePreferences(NotificationPreference preference) async {}

  @override
  Stream<AppNotification> subscribeToNotifications() => const Stream.empty();

  @override
  void clearCache() {}
}

class MockAnnouncementRepository implements IAnnouncementRepository {
  List<Announcement> mockAnnouncements = [
    Announcement(
      id: 'e6000000-0000-0000-0000-000000000001',
      title: 'Welcome to Fall 2026 Academic Term',
      body: 'We are excited to launch the new term across all branches.',
      publishAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Announcement>> getTargetedAnnouncements() async =>
      mockAnnouncements;

  @override
  Future<List<Announcement>> getAllAnnouncementsForAdmin() async =>
      mockAnnouncements;

  @override
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
    required AnnouncementPriority priority,
    required DateTime publishAt,
    DateTime? expiresAt,
    bool requiresAcknowledgement = false,
    required List<AnnouncementTarget> targets,
  }) async => mockAnnouncements.first;

  @override
  Future<void> publishAnnouncement(String announcementId) async {}

  @override
  Future<void> acknowledgeAnnouncement(String announcementId) async {}

  @override
  void clearCache() {}
}

void main() {
  group('Phase 9 Communication Models & ViewModels Unit Tests', () {
    test('ConversationModel parses JSON correctly', () {
      final json = {
        'id': 'e2000000-0000-0000-0000-000000000001',
        'conversation_type': 'direct',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'last_message_at': DateTime.now().toIso8601String(),
        'conversation_members': [],
      };
      final conv = Conversation.fromJson(json, unreadCount: 3);
      expect(conv.id, equals('e2000000-0000-0000-0000-000000000001'));
      expect(conv.conversationType, equals(ConversationType.direct));
      expect(conv.unreadCount, equals(3));
    });

    test('MessageModel parses text message correctly', () {
      final json = {
        'id': 'e4000000-0000-0000-0000-000000000001',
        'conversation_id': 'e2000000-0000-0000-0000-000000000001',
        'sender_id': '00000000-0000-0000-0000-000000000104',
        'message_type': 'text',
        'text_content': 'Hello Student!',
        'sent_at': DateTime.now().toIso8601String(),
      };
      final msg = Message.fromJson(json);
      expect(msg.id, equals('e4000000-0000-0000-0000-000000000001'));
      expect(msg.textContent, equals('Hello Student!'));
      expect(msg.isDeleted, isFalse);
    });

    test(
      'ConversationListViewModel loads conversations and unread counts',
      () async {
        final repo = MockConversationRepository();
        final vm = ConversationListViewModel(repo);
        await vm.loadConversations();

        expect(vm.conversations.length, equals(1));
        expect(vm.totalUnreadCount, equals(2));
        expect(vm.isLoading, isFalse);
      },
    );

    test('NotificationCenterViewModel loads inbox notifications', () async {
      final repo = MockNotificationRepository();
      final vm = NotificationCenterViewModel(repo);
      await vm.loadNotifications();

      expect(vm.notifications.length, equals(1));
      expect(vm.unreadCount, equals(1));
      expect(vm.isLoading, isFalse);
    });

    test('AnnouncementViewModel loads targeted announcements', () async {
      final repo = MockAnnouncementRepository();
      final vm = AnnouncementViewModel(repo);
      await vm.loadTargetedAnnouncements();

      expect(vm.announcements.length, equals(1));
      expect(vm.announcements.first.title, contains('Welcome'));
      expect(vm.isLoading, isFalse);
    });
  });

  group('Phase 9 Communication Widget Tests', () {
    testWidgets(
      'ConversationListScreen renders conversation cards and unread badge',
      (tester) async {
        final vm = ConversationListViewModel(MockConversationRepository());

        await tester.pumpWidget(
          MaterialApp(home: ConversationListScreen(viewModel: vm)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Conversations'), findsOneWidget);
        expect(find.text('Dr. Alan Turing'), findsOneWidget);
        expect(find.text('2 Unread'), findsOneWidget);
      },
    );

    testWidgets('NotificationCenterScreen renders notification items', (
      tester,
    ) async {
      final vm = NotificationCenterViewModel(MockNotificationRepository());

      await tester.pumpWidget(
        MaterialApp(home: NotificationCenterScreen(viewModel: vm)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('New Message from Teacher'), findsOneWidget);
      expect(find.text('Welcome to CS 101!'), findsOneWidget);
    });

    testWidgets('AnnouncementCenterScreen renders announcement cards', (
      tester,
    ) async {
      final vm = AnnouncementViewModel(MockAnnouncementRepository());

      await tester.pumpWidget(
        MaterialApp(home: AnnouncementCenterScreen(viewModel: vm)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('Welcome to Fall 2026 Academic Term'), findsOneWidget);
    });
  });
}
