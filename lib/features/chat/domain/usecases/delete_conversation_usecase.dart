import '../repositories/chat_repository.dart';

class DeleteConversationUseCase {
  final ChatRepository repository;
  DeleteConversationUseCase(this.repository);

  Future<void> call(String chatId) {
    return repository.deleteConversation(chatId);
  }
}
