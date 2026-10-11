import '../repositories/chat_repository.dart';

class MarkAsReadUseCase {
  final ChatRepository repository;
  MarkAsReadUseCase(this.repository);

  Future<void> call(String chatId) {
    return repository.markAsRead(chatId);
  }
}
