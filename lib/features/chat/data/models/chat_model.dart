import 'dart:convert';
import '../../domain/entities/chat_entity.dart';

class ChatModel extends ChatEntity {
  const ChatModel({
    required super.id,
    required super.name,
    super.avatarUrl,
    super.otherParticipantId,
    required super.lastMessage,
    required super.lastMessageTime,
    super.unreadCount = 0,
    super.isPinned = false,
    super.isArchived = false,
    super.isGroup = false,
    super.isOnline = false,
    super.lastSeen,
    super.isTyping = false,
  });

  factory ChatModel.fromEntity(ChatEntity entity) {
    return ChatModel(
      id: entity.id,
      name: entity.name,
      avatarUrl: entity.avatarUrl,
      otherParticipantId: entity.otherParticipantId,
      lastMessage: entity.lastMessage,
      lastMessageTime: entity.lastMessageTime,
      unreadCount: entity.unreadCount,
      isPinned: entity.isPinned,
      isArchived: entity.isArchived,
      isGroup: entity.isGroup,
      isOnline: entity.isOnline,
      lastSeen: entity.lastSeen,
      isTyping: entity.isTyping,
    );
  }

  factory ChatModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
    String currentUserId, {
    Map<String, dynamic>? otherUserData,
    bool? isOnline,
    DateTime? lastSeen,
    bool? isTyping,
  }) {
    final participants = (data['participantIds'] as List<dynamic>?) ?? [];
    final otherId = participants.firstWhere(
      (p) => p.toString() != currentUserId,
      orElse: () => currentUserId,
    ).toString();

    // Fallback support for legacy documents containing participantData
    final legacyParticipantData = (data['participantData'] as Map<String, dynamic>?) ?? {};
    final legacyOtherInfo = (legacyParticipantData[otherId] as Map<String, dynamic>?) ?? {};

    // Prefer live/cached data from users/{uid}, fall back to legacy participantData, then conversation level name
    final resolvedName = (otherUserData?['displayName'] ??
        otherUserData?['name'] ??
        legacyOtherInfo['displayName'] ??
        legacyOtherInfo['name'] ??
        data['name'] ??
        'User') as String;

    final resolvedAvatarUrl = (otherUserData?['photoURL'] ??
        otherUserData?['avatarUrl'] ??
        legacyOtherInfo['photoURL'] ??
        legacyOtherInfo['avatarUrl'] ??
        data['avatarUrl']) as String?;

    DateTime messageTime = DateTime.now();
    final rawTime = data['lastMessageAt'] ?? data['updatedAt'] ?? data['createdAt'];
    if (rawTime != null) {
      if (rawTime is DateTime) {
        messageTime = rawTime;
      } else {
        try {
          // handles Cloud Firestore Timestamp
          messageTime = (rawTime as dynamic).toDate();
        } catch (_) {}
      }
    }

    final unreadMap = (data['unreadCounts'] as Map<String, dynamic>?) ?? {};
    final pinnedList = (data['pinnedBy'] as List<dynamic>?) ?? [];
    final archivedList = (data['archivedBy'] as List<dynamic>?) ?? [];

    // Check typing status from conversation data
    final typingMap = (data['typing'] as Map<String, dynamic>?) ?? {};
    final resolvedTyping = isTyping ?? (typingMap[otherId] == true);

    // Online status and last seen
    final resolvedOnline = isOnline ?? (otherUserData?['isOnline'] as bool? ?? false);
    final resolvedLastSeen = lastSeen ?? (otherUserData?['lastSeen'] as DateTime?);

    return ChatModel(
      id: id,
      name: resolvedName,
      avatarUrl: resolvedAvatarUrl,
      otherParticipantId: otherId,
      lastMessage: (data['lastMessage'] ?? '') as String,
      lastMessageTime: messageTime,
      unreadCount: (unreadMap[currentUserId] as num?)?.toInt() ?? 0,
      isPinned: pinnedList.contains(currentUserId),
      isArchived: archivedList.contains(currentUserId),
      isGroup: data['isGroup'] as bool? ?? false,
      isOnline: resolvedOnline,
      lastSeen: resolvedLastSeen,
      isTyping: resolvedTyping,
    );
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    DateTime? lastSeen;
    final rawLastSeen = json['lastSeen'];
    if (rawLastSeen != null) {
      if (rawLastSeen is String) {
        lastSeen = DateTime.tryParse(rawLastSeen);
      } else if (rawLastSeen is DateTime) {
        lastSeen = rawLastSeen;
      }
    }

    return ChatModel(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      otherParticipantId: json['otherParticipantId'] as String?,
      lastMessage: json['lastMessage'] as String,
      lastMessageTime: DateTime.parse(json['lastMessageTime'] as String),
      unreadCount: json['unreadCount'] as int? ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      isGroup: json['isGroup'] as bool? ?? false,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: lastSeen,
      isTyping: json['isTyping'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'otherParticipantId': otherParticipantId,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'isGroup': isGroup,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'isTyping': isTyping,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory ChatModel.fromJsonString(String jsonString) =>
      ChatModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}
