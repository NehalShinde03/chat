import 'package:equatable/equatable.dart';
import 'message_type.dart';

class MessageEntity extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;
  final MessageType type;
  final String? mediaUrl;
  final int? audioDurationSeconds;
  final MessageEntity? replyToMessage;
  final bool isForwarded;

  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.type = MessageType.text,
    this.mediaUrl,
    this.audioDurationSeconds,
    this.replyToMessage,
    this.isForwarded = false,
  });

  MessageEntity copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    MessageType? type,
    String? mediaUrl,
    int? audioDurationSeconds,
    MessageEntity? replyToMessage,
    bool? isForwarded,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      isForwarded: isForwarded ?? this.isForwarded,
    );
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        senderName,
        text,
        timestamp,
        status,
        type,
        mediaUrl,
        audioDurationSeconds,
        replyToMessage,
        isForwarded,
      ];
}
