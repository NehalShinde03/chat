import '../repositories/chat_repository.dart';

class SetTypingStatusUseCase {
  final ChatRepository repository;

  SetTypingStatusUseCase(this.repository);

  Future<void> call(String chatId, bool isTyping) async {
    return await repository.setTypingStatus(chatId, isTyping);
  }
}
