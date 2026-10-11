import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../auth/data/models/user_model.dart';
import '../../domain/entities/message_type.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

abstract class ChatRemoteDataSource {
  Stream<List<ChatModel>> getChatsStream(
    String currentUserId, {
    bool includeArchived = false,
  });

  Stream<UserModel?> getUserProfileStream(String userId);

  Future<UserModel?> getUserProfile(String userId);

  Stream<List<MessageModel>> getMessagesStream(
    String chatId, {
    int limit = 50,
  });

  Future<List<MessageModel>> loadOlderMessages(
    String chatId, {
    required DateTime beforeTimestamp,
    int limit = 30,
  });

  Future<void> sendMessage({
    required MessageModel message,
    required String receiverId,
    required String receiverName,
    String? receiverAvatar,
    required String currentUserId,
    required String currentUserName,
    String? currentUserAvatar,
    String? currentUserEmail,
  });

  Future<void> markAsRead(String chatId, String currentUserId);

  Future<void> togglePinChat(
    String chatId,
    String currentUserId,
    bool isCurrentlyPinned,
  );

  Future<void> toggleArchiveChat(
    String chatId,
    String currentUserId,
    bool isCurrentlyArchived,
  );

  Future<List<UserModel>> getRegisteredUsers(
    String currentUserId, {
    String? query,
  });

  String resolveConversationId(String userIdA, String userIdB);

  Future<ChatModel> getOrCreateConversation({
    required String currentUserId,
    required String currentUserName,
    String? currentUserAvatar,
    required UserModel otherUser,
  });

  Future<void> deleteMessage(String chatId, String messageId);

  Future<void> deleteConversation(String chatId, String currentUserId);

  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  });

  Stream<bool> getTypingStream(String chatId, String otherUserId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final FirebaseFirestore firestore;

  // In-memory cache for user profiles to avoid redundant reads
  final Map<String, UserModel> _userCache = {};
  final Map<String, Stream<UserModel?>> _userStreamCache = {};

  ChatRemoteDataSourceImpl({required this.firestore});

  @override
  Stream<UserModel?> getUserProfileStream(String userId) {
    if (_userStreamCache.containsKey(userId)) {
      return _userStreamCache[userId]!;
    }

    final stream = firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      final user = UserModel.fromFirestore(snapshot.data()!, snapshot.id);
      _userCache[userId] = user;
      return user;
    }).asBroadcastStream();

    _userStreamCache[userId] = stream;
    return stream;
  }

  @override
  Future<UserModel?> getUserProfile(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final user = UserModel.fromFirestore(doc.data()!, doc.id);
        _userCache[userId] = user;
        return user;
      }
    } catch (_) {}
    return null;
  }

  @override
  Stream<List<ChatModel>> getChatsStream(
    String currentUserId, {
    bool includeArchived = false,
  }) {
    late final StreamController<List<ChatModel>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? convSub;
    final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>> userSubs = {};
    List<QueryDocumentSnapshot<Map<String, dynamic>>> latestDocs = [];
    final Map<String, UserModel> liveUsers = {};

    void emitProcessedChats() {
      if (controller.isClosed) return;

      final list = latestDocs.map((doc) {
        final data = doc.data();
        final participants = (data['participantIds'] as List<dynamic>?) ?? [];
        final otherId = participants.firstWhere(
          (p) => p.toString() != currentUserId,
          orElse: () => currentUserId,
        ).toString();

        final otherUser = liveUsers[otherId] ?? _userCache[otherId];
        final otherUserData = otherUser != null
            ? {
                'displayName': otherUser.name,
                'photoURL': otherUser.avatarUrl,
                'email': otherUser.email,
                'isOnline': otherUser.isOnline,
                'lastSeen': otherUser.lastSeen,
              }
            : null;

        return ChatModel.fromFirestore(
          data,
          doc.id,
          currentUserId,
          otherUserData: otherUserData,
          isOnline: otherUser?.isOnline,
          lastSeen: otherUser?.lastSeen,
        );
      }).where((chat) {
        final doc = latestDocs.firstWhere((d) => d.id == chat.id);
        final deletedBy = (doc.data()['deletedBy'] as List<dynamic>?) ?? [];
        return !deletedBy.contains(currentUserId) && chat.isArchived == includeArchived;
      }).toList();

      list.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });

      controller.add(list);
    }

    controller = StreamController<List<ChatModel>>(
      onListen: () {
        convSub = firestore
            .collection('conversations')
            .where('participantIds', arrayContains: currentUserId)
            .snapshots()
            .listen(
          (convSnapshot) {
            latestDocs = convSnapshot.docs;

            // Collect all unique participant IDs (excluding current user)
            final Set<String> neededUserIds = {};
            for (final doc in latestDocs) {
              final participants = (doc.data()['participantIds'] as List<dynamic>?) ?? [];
              for (final p in participants) {
                final uid = p.toString();
                if (uid != currentUserId && uid.isNotEmpty) {
                  neededUserIds.add(uid);
                }
              }
            }

            // Remove user subscriptions that are no longer needed
            userSubs.removeWhere((uid, sub) {
              if (!neededUserIds.contains(uid)) {
                sub.cancel();
                return true;
              }
              return false;
            });

            // Subscribe to each participant's user document in users/{uid}
            for (final uid in neededUserIds) {
              if (!userSubs.containsKey(uid)) {
                userSubs[uid] = firestore
                    .collection('users')
                    .doc(uid)
                    .snapshots()
                    .listen(
                  (uDoc) {
                    if (uDoc.exists && uDoc.data() != null) {
                      final uModel = UserModel.fromFirestore(uDoc.data()!, uDoc.id);
                      liveUsers[uid] = uModel;
                      _userCache[uid] = uModel;
                    }
                    emitProcessedChats();
                  },
                  onError: (_) {
                    emitProcessedChats();
                  },
                );
              }
            }

            emitProcessedChats();
          },
          onError: (err) {
            if (!controller.isClosed) {
              controller.addError(err);
            }
          },
        );
      },
      onCancel: () async {
        await convSub?.cancel();
        for (final sub in userSubs.values) {
          await sub.cancel();
        }
        userSubs.clear();
      },
    );

    return controller.stream;
  }

  @override
  Stream<List<MessageModel>> getMessagesStream(
    String chatId, {
    int limit = 50,
  }) {
    return firestore
        .collection('conversations')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['isDeleted'] != true;
          })
          .map((doc) => MessageModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<List<MessageModel>> loadOlderMessages(
    String chatId, {
    required DateTime beforeTimestamp,
    int limit = 30,
  }) async {
    final snapshot = await firestore
        .collection('conversations')
        .doc(chatId)
        .collection('messages')
        .where('timestamp', isLessThan: Timestamp.fromDate(beforeTimestamp))
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          return data['isDeleted'] != true;
        })
        .map((doc) => MessageModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> sendMessage({
    required MessageModel message,
    required String receiverId,
    required String receiverName,
    String? receiverAvatar,
    required String currentUserId,
    required String currentUserName,
    String? currentUserAvatar,
    String? currentUserEmail,
  }) async {
    final batch = firestore.batch();

    final msgRef = firestore
        .collection('conversations')
        .doc(message.chatId)
        .collection('messages')
        .doc(message.id);

    final convRef = firestore.collection('conversations').doc(message.chatId);

    final String lastPreview;
    if (message.type == MessageType.audio) {
      lastPreview = '🎤 Voice message';
    } else if (message.type == MessageType.image) {
      lastPreview = '📷 Photo';
    } else {
      lastPreview = message.text;
    }

    // Ensure media payload (image or voice) is accessible to the receiver across devices.
    // If mediaUrl points to a local file, encode it as a self-contained data URI.
    MessageModel messageToSave = message;
    if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
      final mediaPath = message.mediaUrl!;
      if (!mediaPath.startsWith('http://') &&
          !mediaPath.startsWith('https://') &&
          !mediaPath.startsWith('data:')) {
        try {
          final file = File(mediaPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) {
              if (bytes.length > 850 * 1024) {
                debugPrint('ChatRemoteDataSource warning: Media size (${bytes.length} bytes) is approaching Firestore document limit.');
              }
              final base64Payload = base64Encode(bytes);
              if (message.type == MessageType.audio) {
                messageToSave = MessageModel.fromEntity(
                  message.copyWith(mediaUrl: 'data:audio/m4a;base64,$base64Payload'),
                );
              } else if (message.type == MessageType.image) {
                // Determine mime type from extension or default to jpeg
                final ext = mediaPath.split('.').last.toLowerCase();
                final mime = ext == 'png' ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');
                messageToSave = MessageModel.fromEntity(
                  message.copyWith(mediaUrl: 'data:image/$mime;base64,$base64Payload'),
                );
              }
            }
          } else {
            debugPrint('ChatRemoteDataSource: Local media file does not exist at path: $mediaPath');
          }
        } catch (e) {
          debugPrint('Error preparing media payload for message: $e');
        }
      }
    }

    batch.set(msgRef, messageToSave.toFirestore());

    // NOTE: participantData has been removed to avoid duplicate participant data.
    // users/{uid} is the single source of truth for user profiles.
    batch.set(
      convRef,
      {
        'conversationId': message.chatId,
        'participantIds': [currentUserId, receiverId],
        'lastMessage': lastPreview,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
        'unreadCounts': {
          receiverId: FieldValue.increment(1),
          currentUserId: 0,
        },
        'typing': {
          currentUserId: false,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  @override
  Future<void> markAsRead(String chatId, String currentUserId) async {
    try {
      await firestore.collection('conversations').doc(chatId).set({
        'unreadCounts': {
          currentUserId: 0,
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> togglePinChat(
    String chatId,
    String currentUserId,
    bool isCurrentlyPinned,
  ) async {
    await firestore.collection('conversations').doc(chatId).set({
      'pinnedBy': isCurrentlyPinned
          ? FieldValue.arrayRemove([currentUserId])
          : FieldValue.arrayUnion([currentUserId]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> toggleArchiveChat(
    String chatId,
    String currentUserId,
    bool isCurrentlyArchived,
  ) async {
    await firestore.collection('conversations').doc(chatId).set({
      'archivedBy': isCurrentlyArchived
          ? FieldValue.arrayRemove([currentUserId])
          : FieldValue.arrayUnion([currentUserId]),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<UserModel>> getRegisteredUsers(
    String currentUserId, {
    String? query,
  }) async {
    final snapshot = await firestore.collection('users').get();
    final users = snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
        .where((u) {
      if (query == null || query.trim().isEmpty) return true;
      final q = query.trim().toLowerCase();
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();

    for (final u in users) {
      _userCache[u.id] = u;
    }

    return users;
  }

  @override
  String resolveConversationId(String userIdA, String userIdB) {
    return userIdA.compareTo(userIdB) < 0
        ? '${userIdA}_$userIdB'
        : '${userIdB}_$userIdA';
  }

  @override
  Future<ChatModel> getOrCreateConversation({
    required String currentUserId,
    required String currentUserName,
    String? currentUserAvatar,
    required UserModel otherUser,
  }) async {
    // Cache the otherUser profile
    _userCache[otherUser.id] = otherUser;

    final convId = resolveConversationId(currentUserId, otherUser.id);
    final doc = await firestore.collection('conversations').doc(convId).get();
    if (doc.exists && doc.data() != null) {
      return ChatModel.fromFirestore(
        doc.data()!,
        convId,
        currentUserId,
        otherUserData: {
          'displayName': otherUser.name,
          'photoURL': otherUser.avatarUrl,
          'email': otherUser.email,
          'isOnline': otherUser.isOnline,
          'lastSeen': otherUser.lastSeen,
        },
        isOnline: otherUser.isOnline,
        lastSeen: otherUser.lastSeen,
      );
    }
    return ChatModel(
      id: convId,
      name: otherUser.name,
      avatarUrl: otherUser.avatarUrl,
      otherParticipantId: otherUser.id,
      lastMessage: '',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      isPinned: false,
      isArchived: false,
      isGroup: false,
      isOnline: otherUser.isOnline,
      lastSeen: otherUser.lastSeen,
      isTyping: false,
    );
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await firestore
          .collection('conversations')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
      });
    } catch (_) {}
  }

  @override
  Future<void> deleteConversation(String chatId, String currentUserId) async {
    try {
      await firestore.collection('conversations').doc(chatId).update({
        'deletedBy': FieldValue.arrayUnion([currentUserId]),
      });
    } catch (_) {}
  }

  @override
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      await firestore.collection('conversations').doc(chatId).set({
        'typing': {
          userId: isTyping,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating typing status in Firestore: $e');
    }
  }

  @override
  Stream<bool> getTypingStream(String chatId, String otherUserId) {
    return firestore
        .collection('conversations')
        .doc(chatId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return false;
      final typingMap = (snapshot.data()!['typing'] as Map<String, dynamic>?) ?? {};
      return typingMap[otherUserId] == true;
    });
  }
}
