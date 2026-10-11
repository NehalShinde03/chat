import '../repositories/chat_repository.dart';

class GetTypingStreamUseCase {
  final ChatRepository repository;

  GetTypingStreamUseCase(this.repository);

  Stream<bool> call(String chatId, String otherUserId) {
    return repository.getTypingStream(chatId, otherUserId);
  }
}
