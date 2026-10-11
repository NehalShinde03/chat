import 'package:equatable/equatable.dart';

class ChatEntity extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? otherParticipantId;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final bool isGroup;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool isTyping;

  const ChatEntity({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.otherParticipantId,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isArchived = false,
    this.isGroup = false,
    this.isOnline = false,
    this.lastSeen,
    this.isTyping = false,
  });

  ChatEntity copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? otherParticipantId,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isPinned,
    bool? isArchived,
    bool? isGroup,
    bool? isOnline,
    DateTime? lastSeen,
    bool? isTyping,
  }) {
    return ChatEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      otherParticipantId: otherParticipantId ?? this.otherParticipantId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isGroup: isGroup ?? this.isGroup,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isTyping: isTyping ?? this.isTyping,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        avatarUrl,
        otherParticipantId,
        lastMessage,
        lastMessageTime,
        unreadCount,
        isPinned,
        isArchived,
        isGroup,
        isOnline,
        lastSeen,
        isTyping,
      ];
}
