import '../repositories/chat_repository.dart';

class TogglePinChatUseCase {
  final ChatRepository repository;
  TogglePinChatUseCase(this.repository);

  Future<void> call(String chatId, [bool isPinned = false]) {
    return repository.togglePinChat(chatId, isPinned);
  }
}
