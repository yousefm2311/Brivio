import 'package:flutter/foundation.dart';
import '../../../../core/di/injection.dart';
import '../../../admin/domain/models/admin_models.dart';
import '../../../admin/domain/repositories/i_admin_repository.dart';

class AdminAnalyticsViewModel extends ChangeNotifier {
  final IAdminRepository _adminRepository = getIt<IAdminRepository>();

  AdminAnalytics? _analytics;
  AdminAnalytics? get analytics => _analytics;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadAnalytics({DateTime? startDate, DateTime? endDate}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();
      
      _analytics = await _adminRepository.getAnalytics(start, end);
    } catch (e) {
      _errorMessage = 'Failed to load analytics: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
