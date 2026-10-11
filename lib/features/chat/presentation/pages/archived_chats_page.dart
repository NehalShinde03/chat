import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../bloc/chat_list/chat_list_bloc.dart';
import '../bloc/chat_list/chat_list_event.dart';
import '../bloc/chat_list/chat_list_state.dart';
import '../widgets/chat_tile.dart';
import 'chat_room_page.dart';

class ArchivedChatsPage extends StatefulWidget {
  const ArchivedChatsPage({super.key});

  @override
  State<ArchivedChatsPage> createState() => _ArchivedChatsPageState();
}

class _ArchivedChatsPageState extends State<ArchivedChatsPage> {
  @override
  void initState() {
    super.initState();
    context.read<ChatListBloc>().add(const LoadChatsEvent(includeArchived: true));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // Reload normal chats when backing out
          context.read<ChatListBloc>().add(const LoadChatsEvent(includeArchived: false));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.archived),
        ),
        body: BlocBuilder<ChatListBloc, ChatListState>(
          builder: (context, state) {
            if (state is ChatListLoading) {
              return const ChatListSkeleton();
            }

            if (state is ChatListLoaded) {
              if (state.chats.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.archive_outlined,
                  title: AppStrings.noArchivedChats,
                  description:
                      'These chats stay archived when new messages are received.',
                );
              }

              return ListView.separated(
                itemCount: state.chats.length,
                separatorBuilder: (_, _) =>
                    const Divider(indent: 76, height: 1),
                itemBuilder: (context, index) {
                  final chat = state.chats[index];
                  return ChatTile(
                    chat: chat,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatRoomPage(chat: chat),
                        ),
                      );
                    },
                    onTogglePin: () {
                      context
                          .read<ChatListBloc>()
                          .add(TogglePinChatEvent(chat.id));
                    },
                    onToggleArchive: () {
                      context
                          .read<ChatListBloc>()
                          .add(ToggleArchiveChatEvent(chat.id));
                    },
                    onMarkAsRead: () {
                      context
                          .read<ChatListBloc>()
                          .add(MarkChatAsReadEvent(chat.id));
                    },
                    onDelete: () {
                      context
                          .read<ChatListBloc>()
                          .add(DeleteChatEvent(chat.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chat deleted')),
                      );
                    },
                  );
                },
              );
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }
}
