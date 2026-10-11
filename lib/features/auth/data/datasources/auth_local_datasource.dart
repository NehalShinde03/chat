import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<UserModel?> getCachedUser();
  Future<void> cacheUser(UserModel user);
  Future<void> clearCachedUser();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;
  static const String _cachedUserKey = 'CACHED_USER_KEY';

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<UserModel?> getCachedUser() async {
    final jsonString = sharedPreferences.getString(_cachedUserKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        return UserModel.fromJsonString(jsonString);
      } catch (e) {
        throw const CacheException('Failed to parse cached user');
      }
    }
    return null;
  }

  @override
  Future<void> cacheUser(UserModel user) async {
    await sharedPreferences.setString(_cachedUserKey, user.toJsonString());
  }

  @override
  Future<void> clearCachedUser() async {
    await sharedPreferences.remove(_cachedUserKey);
  }
}
