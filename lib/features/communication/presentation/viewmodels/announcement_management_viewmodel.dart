import 'package:flutter/foundation.dart';
import '../../domain/models/announcement.dart';
import '../../domain/repositories/i_announcement_repository.dart';

class AnnouncementManagementViewModel extends ChangeNotifier {
  final IAnnouncementRepository _announcementRepository;

  List<Announcement> _adminAnnouncements = [];
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;

  List<Announcement> get adminAnnouncements => _adminAnnouncements;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get errorMessage => _errorMessage;

  AnnouncementManagementViewModel(this._announcementRepository);

  Future<void> loadAdminAnnouncements() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _adminAnnouncements = await _announcementRepository
          .getAllAnnouncementsForAdmin();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAnnouncement({
    required String title,
    required String body,
    required AnnouncementPriority priority,
    required DateTime publishAt,
    DateTime? expiresAt,
    bool requiresAcknowledgement = false,
    required List<AnnouncementTarget> targets,
  }) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ann = await _announcementRepository.createAnnouncement(
        title: title,
        body: body,
        priority: priority,
        publishAt: publishAt,
        expiresAt: expiresAt,
        requiresAcknowledgement: requiresAcknowledgement,
        targets: targets,
      );

      _adminAnnouncements.insert(0, ann);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<void> publishAnnouncement(String announcementId) async {
    try {
      await _announcementRepository.publishAnnouncement(announcementId);
      final idx = _adminAnnouncements.indexWhere((a) => a.id == announcementId);
      if (idx >= 0) {
        _adminAnnouncements[idx] = _adminAnnouncements[idx].copyWith(
          status: AnnouncementStatus.published,
        );
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
