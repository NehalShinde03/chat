import '../repositories/chat_repository.dart';

class ToggleArchiveChatUseCase {
  final ChatRepository repository;
  ToggleArchiveChatUseCase(this.repository);

  Future<void> call(String chatId, [bool isArchived = false]) {
    return repository.toggleArchiveChat(chatId, isArchived);
  }
}
