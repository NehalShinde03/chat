import '../../../auth/domain/entities/user_entity.dart';
import '../entities/chat_entity.dart';
import '../entities/message_entity.dart';

abstract class ChatRepository {
  Stream<List<ChatEntity>> getChatsStream({bool includeArchived = false});
  Future<List<ChatEntity>> getChats({bool includeArchived = false});
  Stream<UserEntity?> getUserProfileStream(String userId);
  Future<UserEntity?> getUserProfile(String userId);
  Stream<List<MessageEntity>> getMessagesStream(String chatId, {int limit = 50});
  Future<List<MessageEntity>> getMessages(
    String chatId, {
    int page = 0,
    int limit = 20,
    DateTime? beforeTimestamp,
  });
  Future<MessageEntity> sendMessage(
    MessageEntity message, {
    String? receiverId,
    String? receiverName,
    String? receiverAvatar,
  });
  Future<void> togglePinChat(String chatId, [bool isPinned = false]);
  Future<void> toggleArchiveChat(String chatId, [bool isArchived = false]);
  Future<void> forwardMessage(MessageEntity message, List<String> targetChatIds);
  Future<void> markAsRead(String chatId);
  Future<List<ChatEntity>> searchChats(String query);
  Future<List<MessageEntity>> searchMessages(String chatId, String query);
  Future<List<UserEntity>> getRegisteredUsers({String? query});
  Future<void> deleteMessage(String chatId, String messageId);
  Future<void> deleteConversation(String chatId);
  Future<ChatEntity> getOrCreateConversation(UserEntity otherUser);
  String resolveConversationId(String otherUserId);
  Future<void> setTypingStatus(String chatId, bool isTyping);
  Stream<bool> getTypingStream(String chatId, String otherUserId);
}
