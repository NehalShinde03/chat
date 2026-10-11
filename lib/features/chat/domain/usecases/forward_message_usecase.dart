import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class ForwardMessageUseCase {
  final ChatRepository repository;
  ForwardMessageUseCase(this.repository);

  Future<void> call(MessageEntity message, List<String> targetChatIds) {
    return repository.forwardMessage(message, targetChatIds);
  }
}
