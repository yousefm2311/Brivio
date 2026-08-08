import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/announcement.dart';
import '../../domain/repositories/i_announcement_repository.dart';

class SupabaseAnnouncementRepository implements IAnnouncementRepository {
  final SupabaseClientWrapper _clientWrapper;

  SupabaseAnnouncementRepository(this._clientWrapper);

  @override
  Future<List<Announcement>> getTargetedAnnouncements() async {
    final currUser = _clientWrapper.client.auth.currentUser;
    final userId = currUser?.id;

    final response = await _clientWrapper.client
        .from('announcements')
        .select('''
          *,
          announcement_targets (*),
          announcement_reads!left (read_at, acknowledged_at, user_id)
        ''')
        .eq('status', 'published')
        .lte('publish_at', DateTime.now().toIso8601String())
        .order('publish_at', ascending: false);

    final rawList = response as List<dynamic>;
    final announcements = <Announcement>[];
    for (final row in rawList) {
      final item = Map<String, dynamic>.from(row as Map<String, dynamic>);
      if (userId != null && item['announcement_reads'] != null) {
        final reads = (item['announcement_reads'] as List<dynamic>)
            .where((r) => r['user_id'] == userId)
            .toList();
        item['announcement_reads'] = reads;
      }
      announcements.add(Announcement.fromJson(item));
    }
    return announcements;
  }

  @override
  Future<List<Announcement>> getAllAnnouncementsForAdmin() async {
    final response = await _clientWrapper.client
        .from('announcements')
        .select('''
          *,
          announcement_targets (*)
        ''')
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((a) => Announcement.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
    required AnnouncementPriority priority,
    required DateTime publishAt,
    DateTime? expiresAt,
    bool requiresAcknowledgement = false,
    required List<AnnouncementTarget> targets,
  }) async {
    final currUser = _clientWrapper.client.auth.currentUser;
    if (currUser == null) throw Exception('Unauthenticated');

    final annResp = await _clientWrapper.client
        .from('announcements')
        .insert({
          'title': title,
          'body': body,
          'status': 'draft',
          'priority': priority.name,
          'publish_at': publishAt.toIso8601String(),
          'expires_at': expiresAt?.toIso8601String(),
          'requires_acknowledgement': requiresAcknowledgement,
          'created_by': currUser.id,
        })
        .select()
        .single();

    final annId = annResp['id'] as String;

    if (targets.isNotEmpty) {
      final targetPayloads = targets
          .map(
            (t) => {
              'announcement_id': annId,
              'target_type': t.targetType,
              'target_id': t.targetId,
            },
          )
          .toList();

      await _clientWrapper.client
          .from('announcement_targets')
          .insert(targetPayloads);
    }

    final full = await _clientWrapper.client
        .from('announcements')
        .select('*, announcement_targets (*)')
        .eq('id', annId)
        .single();

    return Announcement.fromJson(full);
  }

  @override
  Future<void> publishAnnouncement(String announcementId) async {
    await _clientWrapper.client.rpc(
      'publish_announcement',
      params: {'p_announcement_id': announcementId},
    );
  }

  @override
  Future<void> acknowledgeAnnouncement(String announcementId) async {
    await _clientWrapper.client.rpc(
      'acknowledge_announcement',
      params: {'p_announcement_id': announcementId},
    );
  }

  @override
  void clearCache() {
    // Purge cached references on sign-out
  }
}
