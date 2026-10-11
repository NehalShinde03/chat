import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class GetMessagesUseCase {
  final ChatRepository repository;
  GetMessagesUseCase(this.repository);

  Future<List<MessageEntity>> call(
    String chatId, {
    int page = 0,
    int limit = 20,
    DateTime? beforeTimestamp,
  }) {
    return repository.getMessages(
      chatId,
      page: page,
      limit: limit,
      beforeTimestamp: beforeTimestamp,
    );
  }

  Stream<List<MessageEntity>> stream(String chatId, {int limit = 50}) {
    return repository.getMessagesStream(chatId, limit: limit);
  }
}
