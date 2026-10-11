import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/custom_avatar.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/scroll_to_bottom_fab.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/message_type.dart';
import '../../domain/usecases/get_typing_stream_usecase.dart';
import '../../domain/usecases/get_user_profile_stream_usecase.dart';
import '../../domain/usecases/set_typing_status_usecase.dart';
import '../bloc/chat_list/chat_list_bloc.dart';
import '../bloc/chat_list/chat_list_event.dart';
import '../bloc/chat_list/chat_list_state.dart';
import '../bloc/chat_room/chat_room_bloc.dart';
import '../bloc/chat_room/chat_room_event.dart';
import '../bloc/chat_room/chat_room_state.dart';
import '../widgets/date_group_header.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import 'contact_info_page.dart';
import 'forward_message_dialog.dart';

class ChatRoomPage extends StatefulWidget {
  final ChatEntity chat;

  const ChatRoomPage({super.key, required this.chat});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final _uuid = const Uuid();

  bool _showScrollToBottom = false;
  bool _isSearching = false;
  int _newIncomingMessagesCount = 0;
  int _lastKnownMessageCount = 0;
  bool _hasInitialScrolled = false;
  bool _isScrollingToBottom = false;
  late ChatRoomBloc _chatRoomBloc;

  @override
  void initState() {
    super.initState();
    di.sl<NotificationService>().setCurrentOpenChatId(widget.chat.id);
    _chatRoomBloc = context.read<ChatRoomBloc>();
    _chatRoomBloc.add(LoadMessagesEvent(widget.chat.id));
    context.read<ChatListBloc>().add(MarkChatAsReadEvent(widget.chat.id));

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    di.sl<NotificationService>().setCurrentOpenChatId(null);
    try {
      di.sl<SetTypingStatusUseCase>()(widget.chat.id, false);
    } catch (_) {}
    _chatRoomBloc.add(const ResetChatRoomEvent());
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _getTargetBottomOffset() {
    if (!_scrollController.hasClients) return 0.0;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return 0.0;
    return position.axisDirection == AxisDirection.up
        ? position.minScrollExtent
        : position.maxScrollExtent;
  }

  double _getDistanceFromBottom() {
    if (!_scrollController.hasClients) return 0.0;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return 0.0;
    if (position.axisDirection == AxisDirection.up) {
      return (position.pixels - position.minScrollExtent).abs();
    }
    return (position.maxScrollExtent - position.pixels).abs();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final distanceFromBottom = _getDistanceFromBottom();
    final shouldShowFab = distanceFromBottom > 200;
    if (shouldShowFab != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = shouldShowFab;
        if (!shouldShowFab) {
          _newIncomingMessagesCount = 0;
        }
      });
    }

    // Infinite pagination: when scrolling near top (older messages)
    final position = _scrollController.position;
    final isNearTop = position.axisDirection == AxisDirection.up
        ? (position.maxScrollExtent - position.pixels).abs() <= 150
        : position.pixels <= 150;

    if (isNearTop) {
      context
          .read<ChatRoomBloc>()
          .add(LoadMoreMessagesEvent(widget.chat.id));
    }
  }

  Future<void> _scrollToBottom({bool smooth = true}) async {
    if (!_scrollController.hasClients) return;
    if (_isScrollingToBottom) return;

    _isScrollingToBottom = true;
    if (mounted) {
      setState(() {
        _newIncomingMessagesCount = 0;
      });
    }

    try {
      final position = _scrollController.position;
      final isReversed = position.axisDirection == AxisDirection.up;

      if (!smooth) {
        // Immediate jump with layout convergence
        for (int i = 0; i < 3; i++) {
          if (!_scrollController.hasClients) break;
          final target = _getTargetBottomOffset();
          _scrollController.jumpTo(target);
          await WidgetsBinding.instance.endOfFrame;
        }
        return;
      }

      // If distance from bottom is very large, fast-scroll close to the end
      // to force Flutter to immediately instantiate and layout the bottom messages
      final initialDistance = _getDistanceFromBottom();
      if (initialDistance > 1200) {
        final currentTarget = _getTargetBottomOffset();
        final jumpTarget = isReversed
            ? (currentTarget + 500).clamp(position.minScrollExtent, position.maxScrollExtent)
            : (currentTarget - 500).clamp(position.minScrollExtent, position.maxScrollExtent);
        _scrollController.jumpTo(jumpTarget);
        await WidgetsBinding.instance.endOfFrame;
      }

      // Convergence loop: keep animating to the actual latest extent until settled
      int step = 0;
      while (_scrollController.hasClients && step < 6) {
        step++;
        final target = _getTargetBottomOffset();
        final remaining = (target - _scrollController.position.pixels).abs();

        if (remaining <= 1.5) {
          break;
        }

        final durationMs = (remaining * 0.25).clamp(120.0, 280.0).toInt();
        await _scrollController.animateTo(
          target,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeOutCubic,
        );

        // Allow post-frame layout updates to complete (e.g. image loads, sizing updates)
        await WidgetsBinding.instance.endOfFrame;
      }

      // Final micro-alignment to ensure exact 0px error
      if (_scrollController.hasClients) {
        final finalTarget = _getTargetBottomOffset();
        if ((finalTarget - _scrollController.position.pixels).abs() > 0.5) {
          _scrollController.jumpTo(finalTarget);
        }
      }

      if (mounted) {
        setState(() {
          _showScrollToBottom = false;
          _newIncomingMessagesCount = 0;
        });
      }
    } catch (e) {
      debugPrint('Error in _scrollToBottom: $e');
    } finally {
      _isScrollingToBottom = false;
    }
  }

  void _handleSendMessage(
    String text,
    MessageType type, {
    String? mediaUrl,
    int? duration,
  }) {
    final roomBloc = context.read<ChatRoomBloc>();
    final currentState = roomBloc.state;
    MessageEntity? replyTo;
    if (currentState is ChatRoomLoaded) {
      replyTo = currentState.replyToMessage;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? '';
    final currentUserName = currentUser?.displayName ??
        (currentUser?.email?.split('@').first ?? 'You');

    final newMsg = MessageEntity(
      id: _uuid.v4(),
      chatId: widget.chat.id,
      senderId: currentUserId,
      senderName: currentUserName,
      text: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      type: type,
      mediaUrl: mediaUrl,
      audioDurationSeconds: duration,
      replyToMessage: replyTo,
    );

    roomBloc.add(SendMessageEvent(newMsg));

    // Scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _handleForwardMessage(MessageEntity message) {
    final listState = context.read<ChatListBloc>().state;
    if (listState is! ChatListLoaded) return;

    showDialog(
      context: context,
      builder: (ctx) => ForwardMessageDialog(
        chats: listState.chats,
        message: message,
        onForward: (targetIds) {
          context.read<ChatRoomBloc>().add(
                ForwardMessageEvent(message, targetIds),
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Forwarded to ${targetIds.length} chat(s)'),
              backgroundColor: AppColors.teal,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkChatBackground
          : AppColors.lightChatBackground,
      appBar: _buildAppBar(isDark),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
          // Chat background texture overlay
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.05 : 0.08,
              child: Image.network(
                'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?w=800',
                key: const ValueKey('chat_bg_texture'),
                gaplessPlayback: true,
                cacheWidth: 800,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          ),

          // Message Column & Input
          Column(
            children: [
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  child: BlocConsumer<ChatRoomBloc, ChatRoomState>(
                  listener: (context, state) {
                    if (state is ChatRoomLoaded && !state.isLoadingMore) {
                      final currentCount = state.messages.length;
                      final isInitialLoad = !_hasInitialScrolled && currentCount > 0;

                      if (_lastKnownMessageCount > 0 && currentCount > _lastKnownMessageCount) {
                        final diff = currentCount - _lastKnownMessageCount;
                        if (_showScrollToBottom) {
                          setState(() {
                            _newIncomingMessagesCount += diff;
                          });
                        }
                      }
                      _lastKnownMessageCount = currentCount;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_scrollController.hasClients) return;

                        if (isInitialLoad) {
                          _hasInitialScrolled = true;
                          _scrollToBottom(smooth: false);
                        } else if (!_showScrollToBottom) {
                          // If user is already near bottom, smoothly animate to the newest message
                          _scrollToBottom(smooth: true);
                        }
                      });
                    }
                  },
                  builder: (context, state) {
                    if (state is ChatRoomLoading) {
                      return const ChatMessagesSkeleton();
                    }

                    if (state is ChatRoomLoaded) {
                      final displayMessages = state.searchQuery.isNotEmpty
                          ? state.searchResults
                          : state.messages;

                      if (displayMessages.isEmpty) {
                        return const EmptyStateView(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No messages yet',
                          description:
                              'Send a message, photo, or voice note to begin chatting!',
                        );
                      }

                      // Pre-extract all image messages for the gallery viewer
                      final galleryImages = displayMessages
                          .where((m) => m.type == MessageType.image && m.mediaUrl != null && m.mediaUrl!.isNotEmpty)
                          .toList();

                      return ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: displayMessages.length +
                            (state.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (state.isLoadingMore && index == 0) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }

                        final actualIndex =
                            state.isLoadingMore ? index - 1 : index;
                        final msg = displayMessages[actualIndex];
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                        final isOutgoing = msg.senderId == currentUserId;

                        // Date Grouping logic
                        bool showDateHeader = false;
                        if (actualIndex == 0) {
                          showDateHeader = true;
                        } else {
                          final prevMsg = displayMessages[actualIndex - 1];
                          showDateHeader = !DateFormatter.isSameDay(
                            msg.timestamp,
                            prevMsg.timestamp,
                          );
                        }

                        // WhatsApp Message Grouping logic:
                        // First in group if previous message was different sender, different day, or > 2 minutes apart
                        bool isFirstInGroup = true;
                        if (actualIndex > 0) {
                          final prevMsg = displayMessages[actualIndex - 1];
                          final isSameSender = prevMsg.senderId == msg.senderId;
                          final isSameDay = DateFormatter.isSameDay(prevMsg.timestamp, msg.timestamp);
                          final isCloseInTime = msg.timestamp.difference(prevMsg.timestamp).inSeconds.abs() <= 120;
                          isFirstInGroup = !(isSameSender && isSameDay && isCloseInTime);
                        }

                        // Last in group if next message is different sender, different day, or > 2 minutes apart
                        bool isLastInGroup = true;
                        if (actualIndex < displayMessages.length - 1) {
                          final nextMsg = displayMessages[actualIndex + 1];
                          final isSameSender = nextMsg.senderId == msg.senderId;
                          final isSameDay = DateFormatter.isSameDay(nextMsg.timestamp, msg.timestamp);
                          final isCloseInTime = nextMsg.timestamp.difference(msg.timestamp).inSeconds.abs() <= 120;
                          isLastInGroup = !(isSameSender && isSameDay && isCloseInTime);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateHeader)
                              DateGroupHeader(dateTime: msg.timestamp),
                            MessageBubble(
                              key: ValueKey('msg_bubble_${msg.id}'),
                              message: msg,
                              isOutgoing: isOutgoing,
                              isFirstInGroup: isFirstInGroup,
                              isLastInGroup: isLastInGroup,
                              isGroupChat: widget.chat.isGroup,
                              galleryMessages: galleryImages,
                              onForwardMessage: _handleForwardMessage,
                              onSwipeReply: () {
                                context.read<ChatRoomBloc>().add(
                                      SetReplyMessageEvent(msg),
                                    );
                              },
                              onForward: () => _handleForwardMessage(msg),
                              onDelete: () {
                                context.read<ChatRoomBloc>().add(
                                      DeleteMessageEvent(
                                        chatId: widget.chat.id,
                                        messageId: msg.id,
                                      ),
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Message deleted')),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  }

                  return const SizedBox();
                },
              ),
              ),
            ),

            // Bottom Input Bar
            BlocBuilder<ChatRoomBloc, ChatRoomState>(
              builder: (context, state) {
                MessageEntity? replyTo;
                if (state is ChatRoomLoaded) {
                  replyTo = state.replyToMessage;
                }

                return MessageInputBar(
                  replyToMessage: replyTo,
                  onCancelReply: () {
                    context.read<ChatRoomBloc>().add(
                          const SetReplyMessageEvent(null),
                        );
                  },
                  onSendMessage: _handleSendMessage,
                  onTypingChanged: (isTyping) {
                    di.sl<SetTypingStatusUseCase>()(
                      widget.chat.id,
                      isTyping,
                    );
                  },
                );
              },
            ),
          ],
        ),

        // Scroll to bottom FAB
        Positioned(
          right: 16,
          bottom: 76,
          child: ScrollToBottomFab(
            isVisible: _showScrollToBottom,
            unreadCount: _newIncomingMessagesCount,
            onTap: _scrollToBottom,
          ),
        ),
        ],
      ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    if (_isSearching) {
      return AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search in chat...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            context.read<ChatRoomBloc>().add(
                  SearchRoomMessagesEvent(widget.chat.id, val),
                );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchController.clear();
              });
              context.read<ChatRoomBloc>().add(
                    SearchRoomMessagesEvent(widget.chat.id, ''),
                  );
            },
          ),
        ],
      );
    }

    final otherUserId = widget.chat.otherParticipantId;

    void navigateToGallery() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactInfoPage(chat: widget.chat),
        ),
      );
    }

    return AppBar(
      titleSpacing: 0,
      title: otherUserId != null && otherUserId.isNotEmpty
          ? StreamBuilder<bool>(
              stream: di.sl<GetTypingStreamUseCase>()(widget.chat.id, otherUserId),
              builder: (context, typingSnapshot) {
                final isOtherTyping = typingSnapshot.data == true;

                return StreamBuilder<UserEntity?>(
                  stream: di.sl<GetUserProfileStreamUseCase>()(otherUserId),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final displayName = user?.name ?? widget.chat.name;
                    final avatarUrl = user?.avatarUrl ?? widget.chat.avatarUrl;
                    final isOnline = user?.isOnline ?? widget.chat.isOnline;
                    final lastSeen = user?.lastSeen ?? widget.chat.lastSeen;

                    final String statusText;
                    final Color statusColor;
                    if (isOtherTyping) {
                      statusText = 'typing...';
                      statusColor = const Color(0xFF25D366);
                    } else if (isOnline) {
                      statusText = 'online';
                      statusColor = Colors.white;
                    } else {
                      statusText = DateFormatter.formatLastSeen(lastSeen, isOnline: false);
                      statusColor = Colors.white70;
                    }

                    return InkWell(
                      onTap: navigateToGallery,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            CustomAvatar(
                              name: displayName,
                              imageUrl: avatarUrl,
                              radius: 19,
                              showOnlineIndicator: true,
                              isOnline: isOnline,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      if (isOnline && !isOtherTyping) ...[
                                        Container(
                                          width: 7,
                                          height: 7,
                                          margin: const EdgeInsets.only(right: 5),
                                          decoration: const BoxDecoration(
                                            color: AppColors.greenBadge,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                      Expanded(
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isOtherTyping
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontStyle: isOtherTyping
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            color: statusColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            )
          : InkWell(
              onTap: navigateToGallery,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    CustomAvatar(
                      name: widget.chat.name,
                      imageUrl: widget.chat.avatarUrl,
                      radius: 19,
                      showOnlineIndicator: true,
                      isOnline: widget.chat.isOnline,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.chat.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            DateFormatter.formatLastSeen(
                              widget.chat.lastSeen,
                              isOnline: widget.chat.isOnline,
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search messages',
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (val) {
            if (val == 'gallery' || val == 'media' || val == 'contact_info') {
              navigateToGallery();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'media',
              child: Text('Shared images'),
            ),
          ],
        ),
      ],
    );
  }
}
