import 'package:equatable/equatable.dart';
import '../../../domain/entities/chat_entity.dart';

abstract class ChatListState extends Equatable {
  const ChatListState();

  @override
  List<Object?> get props => [];
}

class ChatListInitial extends ChatListState {}

class ChatListLoading extends ChatListState {}

class ChatListLoaded extends ChatListState {
  final List<ChatEntity> chats;
  final int archivedCount;
  final String searchQuery;

  const ChatListLoaded({
    required this.chats,
    this.archivedCount = 0,
    this.searchQuery = '',
  });

  ChatListLoaded copyWith({
    List<ChatEntity>? chats,
    int? archivedCount,
    String? searchQuery,
  }) {
    return ChatListLoaded(
      chats: chats ?? this.chats,
      archivedCount: archivedCount ?? this.archivedCount,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [chats, archivedCount, searchQuery];
}

class ChatListError extends ChatListState {
  final String message;
  const ChatListError(this.message);

  @override
  List<Object?> get props => [message];
}
