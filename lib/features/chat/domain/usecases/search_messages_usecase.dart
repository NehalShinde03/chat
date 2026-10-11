import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class SearchMessagesUseCase {
  final ChatRepository repository;
  SearchMessagesUseCase(this.repository);

  Future<List<MessageEntity>> call(String chatId, String query) {
    return repository.searchMessages(chatId, query);
  }
}
