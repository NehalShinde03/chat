import '../../../auth/domain/entities/user_entity.dart';
import '../entities/chat_entity.dart';
import '../repositories/chat_repository.dart';

class GetOrCreateConversationUseCase {
  final ChatRepository repository;
  GetOrCreateConversationUseCase(this.repository);

  Future<ChatEntity> call(UserEntity otherUser) {
    return repository.getOrCreateConversation(otherUser);
  }
}
