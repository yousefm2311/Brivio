import 'package:flutter/foundation.dart';
import '../../domain/models/announcement.dart';
import '../../domain/repositories/i_announcement_repository.dart';

class AnnouncementViewModel extends ChangeNotifier {
  final IAnnouncementRepository _announcementRepository;

  List<Announcement> _announcements = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Announcement> get announcements => _announcements;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AnnouncementViewModel(this._announcementRepository);

  Future<void> loadTargetedAnnouncements() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _announcements = await _announcementRepository.getTargetedAnnouncements();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acknowledgeAnnouncement(String announcementId) async {
    try {
      await _announcementRepository.acknowledgeAnnouncement(announcementId);
      final idx = _announcements.indexWhere((a) => a.id == announcementId);
      if (idx >= 0) {
        _announcements[idx] = _announcements[idx].copyWith(
          readAt: DateTime.now(),
          acknowledgedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearState() {
    _announcements = [];
    _errorMessage = null;
    _announcementRepository.clearCache();
    notifyListeners();
  }
}
