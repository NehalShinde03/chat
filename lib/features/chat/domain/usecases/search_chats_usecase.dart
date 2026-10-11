import '../entities/chat_entity.dart';
import '../repositories/chat_repository.dart';

class SearchChatsUseCase {
  final ChatRepository repository;
  SearchChatsUseCase(this.repository);

  Future<List<ChatEntity>> call(String query) {
    return repository.searchChats(query);
  }
}
