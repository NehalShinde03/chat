import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class SendMessageUseCase {
  final ChatRepository repository;
  SendMessageUseCase(this.repository);

  Future<MessageEntity> call(MessageEntity message) {
    return repository.sendMessage(message);
  }
}
