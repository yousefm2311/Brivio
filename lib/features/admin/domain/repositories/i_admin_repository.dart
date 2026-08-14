import '../models/admin_models.dart';

abstract class IAdminRepository {
  // Global Settings
  Future<AdminSetting?> getSetting(String key);
  Future<void> updateSetting(String key, dynamic value);

  // Security / RBAC
  Future<String> createRole(String name, List<String> permissions);
  Future<void> assignRole(String userId, String roleId);
  Future<List<AdminRole>> getRoles();

  // Analytics
  Future<AdminAnalytics> getAnalytics(DateTime startDate, DateTime endDate);

  // Helpdesk Ticketing
  Future<List<HelpdeskTicket>> getTickets();
  Future<HelpdeskTicket> createTicket(
    String subject,
    String description,
    String priority,
  );
  Future<void> updateTicketStatus(String ticketId, String status);

  // User Moderation
  Future<void> moderateUserStatus(
    String userType,
    String userId,
    String status,
  );
}
