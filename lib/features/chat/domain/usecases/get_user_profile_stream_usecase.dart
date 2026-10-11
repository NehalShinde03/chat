import '../../../auth/domain/entities/user_entity.dart';
import '../repositories/chat_repository.dart';

class GetUserProfileStreamUseCase {
  final ChatRepository repository;
  GetUserProfileStreamUseCase(this.repository);

  Stream<UserEntity?> call(String userId) {
    return repository.getUserProfileStream(userId);
  }
}
