import 'dart:typed_data';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/message.dart';
import '../../domain/repositories/i_chat_attachment_repository.dart';

class SupabaseChatAttachmentRepository implements IChatAttachmentRepository {
  final SupabaseClientWrapper _clientWrapper;

  SupabaseChatAttachmentRepository(this._clientWrapper);

  @override
  Future<MessageAttachment> uploadAttachment({
    required String conversationId,
    required String messageId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final storagePath = '$conversationId/$messageId/$fileName';

    await _clientWrapper.client.storage
        .from('chat_attachments')
        .uploadBinary(storagePath, bytes);

    final currUser = _clientWrapper.client.auth.currentUser;
    if (currUser == null) throw Exception('Unauthenticated');

    final response = await _clientWrapper.client
        .from('message_attachments')
        .insert({
          'message_id': messageId,
          'storage_path': storagePath,
          'original_name': fileName,
          'mime_type': mimeType,
          'size_bytes': bytes.length,
          'uploaded_by': currUser.id,
        })
        .select()
        .single();

    final signedUrl = await getSignedUrl(storagePath);
    return MessageAttachment.fromJson(response).copyWith(signedUrl: signedUrl);
  }

  @override
  Future<String> getSignedUrl(String storagePath) async {
    final res = await _clientWrapper.client.storage
        .from('chat_attachments')
        .createSignedUrl(storagePath, 3600);
    return res;
  }
}
