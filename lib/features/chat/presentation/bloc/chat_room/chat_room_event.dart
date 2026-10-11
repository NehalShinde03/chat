import 'package:equatable/equatable.dart';
import '../../../domain/entities/message_entity.dart';

abstract class ChatRoomEvent extends Equatable {
  const ChatRoomEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessagesEvent extends ChatRoomEvent {
  final String chatId;
  final bool isRefresh;
  const LoadMessagesEvent(this.chatId, {this.isRefresh = false});

  @override
  List<Object?> get props => [chatId, isRefresh];
}

class LoadMoreMessagesEvent extends ChatRoomEvent {
  final String chatId;
  const LoadMoreMessagesEvent(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class SendMessageEvent extends ChatRoomEvent {
  final MessageEntity message;
  const SendMessageEvent(this.message);

  @override
  List<Object?> get props => [message];
}

class SetReplyMessageEvent extends ChatRoomEvent {
  final MessageEntity? message;
  const SetReplyMessageEvent(this.message);

  @override
  List<Object?> get props => [message];
}

class ForwardMessageEvent extends ChatRoomEvent {
  final MessageEntity message;
  final List<String> targetChatIds;
  const ForwardMessageEvent(this.message, this.targetChatIds);

  @override
  List<Object?> get props => [message, targetChatIds];
}

class SearchRoomMessagesEvent extends ChatRoomEvent {
  final String chatId;
  final String query;
  const SearchRoomMessagesEvent(this.chatId, this.query);

  @override
  List<Object?> get props => [chatId, query];
}

class IncomingMessageReceivedEvent extends ChatRoomEvent {
  final MessageEntity message;
  const IncomingMessageReceivedEvent(this.message);

  @override
  List<Object?> get props => [message];
}

class MessagesStreamUpdatedEvent extends ChatRoomEvent {
  final List<MessageEntity> messages;
  const MessagesStreamUpdatedEvent(this.messages);

  @override
  List<Object?> get props => [messages];
}

class DeleteMessageEvent extends ChatRoomEvent {
  final String chatId;
  final String messageId;
  const DeleteMessageEvent({required this.chatId, required this.messageId});

  @override
  List<Object?> get props => [chatId, messageId];
}

class ResetChatRoomEvent extends ChatRoomEvent {
  const ResetChatRoomEvent();
}
