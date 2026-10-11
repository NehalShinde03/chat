import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      final remoteUser = await remoteDataSource.getCurrentUser();
      if (remoteUser != null) {
        await localDataSource.cacheUser(remoteUser);
        return remoteUser;
      }
    } catch (_) {
      // Fallback to local cache if network/remote fails
    }
    return await localDataSource.getCachedUser();
  }

  @override
  Future<UserEntity?> signInWithGoogle() async {
    try {
      final user = await remoteDataSource.signInWithGoogle();
      if (user != null) {
        await localDataSource.cacheUser(user);
      }
      return user;
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await remoteDataSource.signOut();
    } catch (_) {}
    await localDataSource.clearCachedUser();
  }

  @override
  Stream<UserEntity?> get authStateChanges =>
      remoteDataSource.authStateChanges;
}
