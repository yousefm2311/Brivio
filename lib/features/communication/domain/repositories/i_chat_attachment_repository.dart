import 'dart:typed_data';
import '../models/message.dart';

abstract class IChatAttachmentRepository {
  Future<MessageAttachment> uploadAttachment({
    required String conversationId,
    required String messageId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  });

  Future<String> getSignedUrl(String storagePath);
}
