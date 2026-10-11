import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/message_entity.dart';
import '../../../domain/usecases/delete_message_usecase.dart';
import '../../../domain/usecases/forward_message_usecase.dart';
import '../../../domain/usecases/get_messages_usecase.dart';
import '../../../domain/usecases/search_messages_usecase.dart';
import '../../../domain/usecases/send_message_usecase.dart';
import 'chat_room_event.dart';
import 'chat_room_state.dart';

class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  final GetMessagesUseCase getMessagesUseCase;
  final SendMessageUseCase sendMessageUseCase;
  final ForwardMessageUseCase forwardMessageUseCase;
  final SearchMessagesUseCase searchMessagesUseCase;
  final DeleteMessageUseCase deleteMessageUseCase;

  static const int _pageSize = 30;
  StreamSubscription<List<MessageEntity>>? _messagesSubscription;
  String? _activeChatId;
  List<MessageEntity> _currentMessages = [];

  ChatRoomBloc({
    required this.getMessagesUseCase,
    required this.sendMessageUseCase,
    required this.forwardMessageUseCase,
    required this.searchMessagesUseCase,
    required this.deleteMessageUseCase,
  }) : super(ChatRoomInitial()) {
    on<LoadMessagesEvent>(_onLoadMessages);
    on<MessagesStreamUpdatedEvent>(_onMessagesStreamUpdated);
    on<LoadMoreMessagesEvent>(_onLoadMoreMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<SetReplyMessageEvent>(_onSetReplyMessage);
    on<ForwardMessageEvent>(_onForwardMessage);
    on<SearchRoomMessagesEvent>(_onSearchRoomMessages);
    on<IncomingMessageReceivedEvent>(_onIncomingMessageReceived);
    on<DeleteMessageEvent>(_onDeleteMessage);
    on<ResetChatRoomEvent>(_onResetChatRoom);
  }

  void _onResetChatRoom(
    ResetChatRoomEvent event,
    Emitter<ChatRoomState> emit,
  ) {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _activeChatId = null;
    _currentMessages = [];
    emit(ChatRoomInitial());
  }

  Future<void> _onLoadMessages(
    LoadMessagesEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    // If opening a new or different chat room, immediately clear old messages
    // to prevent temporary leak/blink of old user conversation data
    if (_activeChatId != event.chatId || event.isRefresh) {
      await _messagesSubscription?.cancel();
      _messagesSubscription = null;
      _activeChatId = event.chatId;
      _currentMessages = [];
      emit(ChatRoomLoading());
    } else {
      _activeChatId = event.chatId;
    }

    final requestedChatId = event.chatId;
    await _messagesSubscription?.cancel();
    _messagesSubscription = getMessagesUseCase
        .stream(requestedChatId, limit: _pageSize)
        .listen(
      (messages) {
        if (_activeChatId == requestedChatId) {
          add(MessagesStreamUpdatedEvent(messages));
        }
      },
      onError: (err) {
        if (_activeChatId == requestedChatId) {
          emit(ChatRoomError(err.toString()));
        }
      },
    );
  }

  void _onMessagesStreamUpdated(
    MessagesStreamUpdatedEvent event,
    Emitter<ChatRoomState> emit,
  ) {
    // Firestore streams return in descending order; sort ascending for chronological display
    final sorted = List<MessageEntity>.from(event.messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _currentMessages = sorted;

    final currentState = state;
    MessageEntity? replyTo;
    String query = '';
    List<MessageEntity> searchResults = [];

    if (currentState is ChatRoomLoaded) {
      replyTo = currentState.replyToMessage;
      query = currentState.searchQuery;
      if (query.isNotEmpty) {
        searchResults = sorted
            .where((m) => m.text.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    }

    emit(ChatRoomLoaded(
      messages: sorted,
      hasMore: event.messages.length >= _pageSize,
      currentPage: 0,
      replyToMessage: replyTo,
      searchQuery: query,
      searchResults: searchResults,
    ));
  }

  Future<void> _onLoadMoreMessages(
    LoadMoreMessagesEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (state is! ChatRoomLoaded) return;
    final currentState = state as ChatRoomLoaded;
    if (!currentState.hasMore || currentState.isLoadingMore) return;
    if (_currentMessages.isEmpty) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final oldestTimestamp = _currentMessages.first.timestamp;
      final olderMessages = await getMessagesUseCase(
        event.chatId,
        beforeTimestamp: oldestTimestamp,
        limit: _pageSize,
      );

      if (olderMessages.isEmpty) {
        emit(currentState.copyWith(
          hasMore: false,
          isLoadingMore: false,
        ));
      } else {
        olderMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final combined = [...olderMessages, ..._currentMessages];
        _currentMessages = combined;
        emit(currentState.copyWith(
          messages: combined,
          hasMore: olderMessages.length >= _pageSize,
          isLoadingMore: false,
          currentPage: currentState.currentPage + 1,
        ));
      }
    } catch (_) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    try {
      if (state is ChatRoomLoaded) {
        emit((state as ChatRoomLoaded).copyWith(clearReplyToMessage: true));
      }
      await sendMessageUseCase(event.message);
    } catch (e) {
      debugPrint('Failed to send message: $e');
      if (state is! ChatRoomLoaded) {
        emit(ChatRoomError(e.toString()));
      }
    }
  }

  void _onSetReplyMessage(
    SetReplyMessageEvent event,
    Emitter<ChatRoomState> emit,
  ) {
    if (state is ChatRoomLoaded) {
      final currentState = state as ChatRoomLoaded;
      emit(currentState.copyWith(
        replyToMessage: event.message,
        clearReplyToMessage: event.message == null,
      ));
    }
  }

  Future<void> _onForwardMessage(
    ForwardMessageEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    try {
      await forwardMessageUseCase(event.message, event.targetChatIds);
    } catch (e) {
      emit(ChatRoomError(e.toString()));
    }
  }

  Future<void> _onSearchRoomMessages(
    SearchRoomMessagesEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (state is! ChatRoomLoaded) return;
    final currentState = state as ChatRoomLoaded;
    final q = event.query.trim().toLowerCase();

    if (q.isEmpty) {
      emit(currentState.copyWith(
        searchQuery: '',
        searchResults: [],
      ));
      return;
    }

    final results = _currentMessages
        .where((m) => m.text.toLowerCase().contains(q))
        .toList();

    emit(currentState.copyWith(
      searchQuery: event.query,
      searchResults: results,
    ));
  }

  void _onIncomingMessageReceived(
    IncomingMessageReceivedEvent event,
    Emitter<ChatRoomState> emit,
  ) {
    if (state is ChatRoomLoaded && event.message.chatId == _activeChatId) {
      final currentState = state as ChatRoomLoaded;
      if (!currentState.messages.any((m) => m.id == event.message.id)) {
        final updated = [...currentState.messages, event.message];
        _currentMessages = updated;
        emit(currentState.copyWith(messages: updated));
      }
    }
  }

  Future<void> _onDeleteMessage(
    DeleteMessageEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (state is ChatRoomLoaded) {
      final currentState = state as ChatRoomLoaded;
      final updated = currentState.messages.where((m) => m.id != event.messageId).toList();
      _currentMessages = updated;

      final updatedSearch = currentState.searchResults.where((m) => m.id != event.messageId).toList();
      final replyTo = currentState.replyToMessage?.id == event.messageId ? null : currentState.replyToMessage;

      emit(currentState.copyWith(
        messages: updated,
        searchResults: updatedSearch,
        replyToMessage: replyTo,
        clearReplyToMessage: replyTo == null,
      ));
    }

    try {
      await deleteMessageUseCase(event.chatId, event.messageId);
    } catch (e) {
      emit(ChatRoomError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }
}
