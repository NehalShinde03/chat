import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/message_type.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    required super.senderName,
    required super.text,
    required super.timestamp,
    super.status = MessageStatus.sent,
    super.type = MessageType.text,
    super.mediaUrl,
    super.audioDurationSeconds,
    super.replyToMessage,
    super.isForwarded = false,
  });

  factory MessageModel.fromEntity(MessageEntity entity) {
    return MessageModel(
      id: entity.id,
      chatId: entity.chatId,
      senderId: entity.senderId,
      senderName: entity.senderName,
      text: entity.text,
      timestamp: entity.timestamp,
      status: entity.status,
      type: entity.type,
      mediaUrl: entity.mediaUrl,
      audioDurationSeconds: entity.audioDurationSeconds,
      replyToMessage: entity.replyToMessage,
      isForwarded: entity.isForwarded,
    );
  }

  factory MessageModel.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime msgTime = DateTime.now();
    final rawTs = data['timestamp'];
    if (rawTs != null) {
      if (rawTs is DateTime) {
        msgTime = rawTs;
      } else {
        try {
          msgTime = (rawTs as dynamic).toDate();
        } catch (_) {}
      }
    }

    return MessageModel(
      id: id,
      chatId: (data['chatId'] ?? data['conversationId'] ?? '') as String,
      senderId: (data['senderId'] ?? '') as String,
      senderName: (data['senderName'] ?? '') as String,
      text: (data['text'] ?? '') as String,
      timestamp: msgTime,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => MessageStatus.sent,
      ),
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: data['mediaUrl'] as String?,
      audioDurationSeconds: data['audioDurationSeconds'] as int?,
      replyToMessage: data['replyToMessage'] != null
          ? MessageModel.fromJson(
              Map<String, dynamic>.from(data['replyToMessage'] as Map),
            )
          : null,
      isForwarded: data['isForwarded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'status': status.name,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'audioDurationSeconds': audioDurationSeconds,
      'replyToMessage': replyToMessage != null
          ? (replyToMessage is MessageModel
              ? (replyToMessage as MessageModel).toJson()
              : MessageModel.fromEntity(replyToMessage!).toJson())
          : null,
      'isForwarded': isForwarded,
    };
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      chatId: json['chatId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: json['mediaUrl'] as String?,
      audioDurationSeconds: json['audioDurationSeconds'] as int?,
      replyToMessage: json['replyToMessage'] != null
          ? MessageModel.fromJson(
              json['replyToMessage'] as Map<String, dynamic>,
            )
          : null,
      isForwarded: json['isForwarded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'audioDurationSeconds': audioDurationSeconds,
      'replyToMessage': replyToMessage != null
          ? (MessageModel.fromEntity(replyToMessage!).toJson())
          : null,
      'isForwarded': isForwarded,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory MessageModel.fromJsonString(String jsonString) =>
      MessageModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}
