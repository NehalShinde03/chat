import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/chat_entity.dart';
import '../../../domain/usecases/delete_conversation_usecase.dart';
import '../../../domain/usecases/get_chats_usecase.dart';
import '../../../domain/usecases/mark_as_read_usecase.dart';
import '../../../domain/usecases/search_chats_usecase.dart';
import '../../../domain/usecases/toggle_archive_chat_usecase.dart';
import '../../../domain/usecases/toggle_pin_chat_usecase.dart';
import 'chat_list_event.dart';
import 'chat_list_state.dart';

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  final GetChatsUseCase getChatsUseCase;
  final SearchChatsUseCase searchChatsUseCase;
  final TogglePinChatUseCase togglePinChatUseCase;
  final ToggleArchiveChatUseCase toggleArchiveChatUseCase;
  final MarkAsReadUseCase markAsReadUseCase;
  final DeleteConversationUseCase deleteConversationUseCase;

  StreamSubscription<List<ChatEntity>>? _chatsSubscription;
  List<ChatEntity> _allChats = [];

  ChatListBloc({
    required this.getChatsUseCase,
    required this.searchChatsUseCase,
    required this.togglePinChatUseCase,
    required this.toggleArchiveChatUseCase,
    required this.markAsReadUseCase,
    required this.deleteConversationUseCase,
  }) : super(ChatListInitial()) {
    on<LoadChatsEvent>(_onLoadChats);
    on<ChatsUpdatedEvent>(_onChatsUpdated);
    on<SearchChatsEvent>(_onSearchChats);
    on<TogglePinChatEvent>(_onTogglePinChat);
    on<ToggleArchiveChatEvent>(_onToggleArchiveChat);
    on<MarkChatAsReadEvent>(_onMarkChatAsRead);
    on<DeleteChatEvent>(_onDeleteChat);
    on<ResetChatListEvent>(_onResetChatList);
  }

  void _onResetChatList(
    ResetChatListEvent event,
    Emitter<ChatListState> emit,
  ) {
    _chatsSubscription?.cancel();
    _chatsSubscription = null;
    _allChats = [];
    emit(ChatListInitial());
  }

  Future<void> _onLoadChats(
    LoadChatsEvent event,
    Emitter<ChatListState> emit,
  ) async {
    if (state is! ChatListLoaded) {
      emit(ChatListLoading());
    }

    await _chatsSubscription?.cancel();
    _chatsSubscription = getChatsUseCase
        .stream(includeArchived: event.includeArchived)
        .listen(
      (chats) {
        add(ChatsUpdatedEvent(chats));
      },
      onError: (error) {
        emit(ChatListError(error.toString()));
      },
    );
  }

  void _onChatsUpdated(
    ChatsUpdatedEvent event,
    Emitter<ChatListState> emit,
  ) {
    _allChats = event.chats;
    emit(ChatListLoaded(
      chats: event.chats,
      archivedCount: event.chats.where((c) => c.isArchived).length,
    ));
  }

  Future<void> _onSearchChats(
    SearchChatsEvent event,
    Emitter<ChatListState> emit,
  ) async {
    final query = event.query.trim().toLowerCase();
    if (query.isEmpty) {
      emit(ChatListLoaded(
        chats: _allChats,
        searchQuery: '',
      ));
      return;
    }
    final filtered = _allChats.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.lastMessage.toLowerCase().contains(query);
    }).toList();

    emit(ChatListLoaded(
      chats: filtered,
      searchQuery: event.query,
    ));
  }

  Future<void> _onTogglePinChat(
    TogglePinChatEvent event,
    Emitter<ChatListState> emit,
  ) async {
    try {
      final index = _allChats.indexWhere((c) => c.id == event.chatId);
      final isPinned = index != -1 ? _allChats[index].isPinned : false;
      await togglePinChatUseCase(event.chatId, isPinned);
    } catch (e) {
      emit(ChatListError(e.toString()));
    }
  }

  Future<void> _onToggleArchiveChat(
    ToggleArchiveChatEvent event,
    Emitter<ChatListState> emit,
  ) async {
    try {
      final index = _allChats.indexWhere((c) => c.id == event.chatId);
      final isArchived = index != -1 ? _allChats[index].isArchived : false;
      await toggleArchiveChatUseCase(event.chatId, isArchived);
    } catch (e) {
      emit(ChatListError(e.toString()));
    }
  }

  Future<void> _onMarkChatAsRead(
    MarkChatAsReadEvent event,
    Emitter<ChatListState> emit,
  ) async {
    try {
      await markAsReadUseCase(event.chatId);
    } catch (e) {
      emit(ChatListError(e.toString()));
    }
  }

  Future<void> _onDeleteChat(
    DeleteChatEvent event,
    Emitter<ChatListState> emit,
  ) async {
    final updatedAll = _allChats.where((c) => c.id != event.chatId).toList();
    _allChats = updatedAll;

    if (state is ChatListLoaded) {
      final currentState = state as ChatListLoaded;
      final updatedList = currentState.chats.where((c) => c.id != event.chatId).toList();
      emit(currentState.copyWith(
        chats: updatedList,
        archivedCount: updatedAll.where((c) => c.isArchived).length,
      ));
    }

    try {
      await deleteConversationUseCase(event.chatId);
    } catch (e) {
      emit(ChatListError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _chatsSubscription?.cancel();
    return super.close();
  }
}
