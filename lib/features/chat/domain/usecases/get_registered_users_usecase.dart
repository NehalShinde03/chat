import '../../../auth/domain/entities/user_entity.dart';
import '../repositories/chat_repository.dart';

class GetRegisteredUsersUseCase {
  final ChatRepository repository;
  GetRegisteredUsersUseCase(this.repository);

  Future<List<UserEntity>> call({String? query}) {
    return repository.getRegisteredUsers(query: query);
  }
}
