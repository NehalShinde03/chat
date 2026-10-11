import 'package:equatable/equatable.dart';
import '../../../domain/entities/message_entity.dart';

abstract class ChatRoomState extends Equatable {
  const ChatRoomState();

  @override
  List<Object?> get props => [];
}

class ChatRoomInitial extends ChatRoomState {}

class ChatRoomLoading extends ChatRoomState {}

class ChatRoomLoaded extends ChatRoomState {
  final List<MessageEntity> messages;
  final bool hasMore;
  final bool isLoadingMore;
  final int currentPage;
  final MessageEntity? replyToMessage;
  final String searchQuery;
  final List<MessageEntity> searchResults;

  const ChatRoomLoaded({
    required this.messages,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.currentPage = 0,
    this.replyToMessage,
    this.searchQuery = '',
    this.searchResults = const [],
  });

  ChatRoomLoaded copyWith({
    List<MessageEntity>? messages,
    bool? hasMore,
    bool? isLoadingMore,
    int? currentPage,
    MessageEntity? replyToMessage,
    bool clearReplyToMessage = false,
    String? searchQuery,
    List<MessageEntity>? searchResults,
  }) {
    return ChatRoomLoaded(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentPage: currentPage ?? this.currentPage,
      replyToMessage:
          clearReplyToMessage ? null : (replyToMessage ?? this.replyToMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        hasMore,
        isLoadingMore,
        currentPage,
        replyToMessage,
        searchQuery,
        searchResults,
      ];
}

class ChatRoomError extends ChatRoomState {
  final String message;
  const ChatRoomError(this.message);

  @override
  List<Object?> get props => [message];
}
