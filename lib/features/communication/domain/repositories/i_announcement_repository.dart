import '../models/announcement.dart';

abstract class IAnnouncementRepository {
  Future<List<Announcement>> getTargetedAnnouncements();
  Future<List<Announcement>> getAllAnnouncementsForAdmin();
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
    required AnnouncementPriority priority,
    required DateTime publishAt,
    DateTime? expiresAt,
    bool requiresAcknowledgement = false,
    required List<AnnouncementTarget> targets,
  });

  Future<void> publishAnnouncement(String announcementId);
  Future<void> acknowledgeAnnouncement(String announcementId);
  void clearCache();
}
