import '../entities/chat_entity.dart';
import '../repositories/chat_repository.dart';

class GetChatsUseCase {
  final ChatRepository repository;
  GetChatsUseCase(this.repository);

  Future<List<ChatEntity>> call({bool includeArchived = false}) {
    return repository.getChats(includeArchived: includeArchived);
  }

  Stream<List<ChatEntity>> stream({bool includeArchived = false}) {
    return repository.getChatsStream(includeArchived: includeArchived);
  }
}
