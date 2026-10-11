import 'package:equatable/equatable.dart';
import '../../../domain/entities/chat_entity.dart';

abstract class ChatListEvent extends Equatable {
  const ChatListEvent();

  @override
  List<Object?> get props => [];
}

class LoadChatsEvent extends ChatListEvent {
  final bool includeArchived;
  const LoadChatsEvent({this.includeArchived = false});

  @override
  List<Object?> get props => [includeArchived];
}

class SearchChatsEvent extends ChatListEvent {
  final String query;
  const SearchChatsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class TogglePinChatEvent extends ChatListEvent {
  final String chatId;
  const TogglePinChatEvent(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class ToggleArchiveChatEvent extends ChatListEvent {
  final String chatId;
  const ToggleArchiveChatEvent(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class MarkChatAsReadEvent extends ChatListEvent {
  final String chatId;
  const MarkChatAsReadEvent(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class ChatsUpdatedEvent extends ChatListEvent {
  final List<ChatEntity> chats;
  const ChatsUpdatedEvent(this.chats);

  @override
  List<Object?> get props => [chats];
}

class DeleteChatEvent extends ChatListEvent {
  final String chatId;
  const DeleteChatEvent(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class ResetChatListEvent extends ChatListEvent {
  const ResetChatListEvent();
}
