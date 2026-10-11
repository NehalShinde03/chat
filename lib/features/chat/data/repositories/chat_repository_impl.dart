import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatLocalDataSource localDataSource;
  final ChatRemoteDataSource remoteDataSource;
  final FirebaseAuth firebaseAuth;
  final _uuid = const Uuid();

  ChatRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.firebaseAuth,
  });

  String get _currentUserId => firebaseAuth.currentUser?.uid ?? '';
  String get _currentUserName =>
      firebaseAuth.currentUser?.displayName ??
      (firebaseAuth.currentUser?.email?.split('@').first ?? 'User');
  String? get _currentUserAvatar => firebaseAuth.currentUser?.photoURL;
  String? get _currentUserEmail => firebaseAuth.currentUser?.email;

  @override
  Stream<List<ChatEntity>> getChatsStream({bool includeArchived = false}) {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }
    return remoteDataSource
        .getChatsStream(_currentUserId, includeArchived: includeArchived)
        .map((chats) {
      // Background save to local cache for offline resumption
      localDataSource.saveChats(chats);
      return chats;
    });
  }

  @override
  Stream<UserEntity?> getUserProfileStream(String userId) {
    return remoteDataSource.getUserProfileStream(userId);
  }

  @override
  Future<UserEntity?> getUserProfile(String userId) {
    return remoteDataSource.getUserProfile(userId);
  }

  @override
  Future<List<ChatEntity>> getChats({bool includeArchived = false}) async {
    try {
      final cached = await localDataSource.getChats();
      if (cached.isNotEmpty) {
        return cached.where((c) => c.isArchived == includeArchived).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Stream<List<MessageEntity>> getMessagesStream(
    String chatId, {
    int limit = 50,
  }) {
    return remoteDataSource.getMessagesStream(chatId, limit: limit).map((msgs) {
      localDataSource.saveMessages(chatId, msgs);
      return msgs;
    });
  }

  @override
  Future<List<MessageEntity>> getMessages(
    String chatId, {
    int page = 0,
    int limit = 20,
    DateTime? beforeTimestamp,
  }) async {
    if (beforeTimestamp != null) {
      return await remoteDataSource.loadOlderMessages(
        chatId,
        beforeTimestamp: beforeTimestamp,
        limit: limit,
      );
    }
    final cached = await localDataSource.getMessages(chatId);
    return cached;
  }

  @override
  Future<MessageEntity> sendMessage(
    MessageEntity message, {
    String? receiverId,
    String? receiverName,
    String? receiverAvatar,
  }) async {
    String targetReceiverId = receiverId ?? '';
    if (targetReceiverId.isEmpty) {
      // Extract from conversation ID (if deterministic: uidA_uidB)
      final parts = message.chatId.split('_');
      if (parts.length == 2) {
        targetReceiverId =
            parts[0] == _currentUserId ? parts[1] : parts[0];
      }
    }

    final messageModel = MessageModel.fromEntity(message);

    await remoteDataSource.sendMessage(
      message: messageModel,
      receiverId: targetReceiverId,
      receiverName: receiverName ?? 'User',
      receiverAvatar: receiverAvatar,
      currentUserId: _currentUserId,
      currentUserName: _currentUserName,
      currentUserAvatar: _currentUserAvatar,
      currentUserEmail: _currentUserEmail,
    );

    return message;
  }

  @override
  Future<void> togglePinChat(String chatId, [bool isPinned = false]) async {
    if (_currentUserId.isNotEmpty) {
      await remoteDataSource.togglePinChat(chatId, _currentUserId, isPinned);
    }
  }

  @override
  Future<void> toggleArchiveChat(String chatId, [bool isArchived = false]) async {
    if (_currentUserId.isNotEmpty) {
      await remoteDataSource.toggleArchiveChat(
        chatId,
        _currentUserId,
        isArchived,
      );
    }
  }

  @override
  Future<void> forwardMessage(
    MessageEntity message,
    List<String> targetChatIds,
  ) async {
    for (final targetChatId in targetChatIds) {
      final fwd = message.copyWith(
        id: _uuid.v4(),
        chatId: targetChatId,
        senderId: _currentUserId,
        senderName: _currentUserName,
        timestamp: DateTime.now(),
        isForwarded: true,
      );
      await sendMessage(fwd);
    }
  }

  @override
  Future<void> markAsRead(String chatId) async {
    if (_currentUserId.isNotEmpty) {
      await remoteDataSource.markAsRead(chatId, _currentUserId);
    }
  }

  @override
  Future<List<ChatEntity>> searchChats(String query) async {
    final cached = await localDataSource.getChats();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return cached;
    return cached
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.lastMessage.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<List<MessageEntity>> searchMessages(
    String chatId,
    String query,
  ) async {
    final cached = await localDataSource.getMessages(chatId);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return cached;
    return cached.where((m) => m.text.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<UserEntity>> getRegisteredUsers({String? query}) async {
    return await remoteDataSource.getRegisteredUsers(
      _currentUserId,
      query: query,
    );
  }

  @override
  Future<ChatEntity> getOrCreateConversation(UserEntity otherUser) async {
    final otherModel = UserModel(
      id: otherUser.id,
      name: otherUser.name,
      email: otherUser.email,
      avatarUrl: otherUser.avatarUrl,
      phoneNumber: otherUser.phoneNumber,
      statusMessage: otherUser.statusMessage,
    );

    return await remoteDataSource.getOrCreateConversation(
      currentUserId: _currentUserId,
      currentUserName: _currentUserName,
      currentUserAvatar: _currentUserAvatar,
      otherUser: otherModel,
    );
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {
    await localDataSource.deleteMessage(chatId, messageId);
    await remoteDataSource.deleteMessage(chatId, messageId);
  }

  @override
  Future<void> deleteConversation(String chatId) async {
    await localDataSource.deleteConversation(chatId);
    if (_currentUserId.isNotEmpty) {
      await remoteDataSource.deleteConversation(chatId, _currentUserId);
    }
  }

  @override
  String resolveConversationId(String otherUserId) {
    return remoteDataSource.resolveConversationId(_currentUserId, otherUserId);
  }

  @override
  Future<void> setTypingStatus(String chatId, bool isTyping) async {
    if (_currentUserId.isEmpty) return;
    await remoteDataSource.setTypingStatus(
      chatId: chatId,
      userId: _currentUserId,
      isTyping: isTyping,
    );
  }

  @override
  Stream<bool> getTypingStream(String chatId, String otherUserId) {
    return remoteDataSource.getTypingStream(chatId, otherUserId);
  }
}
