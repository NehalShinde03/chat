import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/widgets/custom_avatar.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../domain/entities/chat_entity.dart';
import '../bloc/chat_list/chat_list_bloc.dart';
import '../bloc/chat_list/chat_list_event.dart';
import '../bloc/chat_list/chat_list_state.dart';
import '../widgets/chat_tile.dart';
import 'archived_chats_page.dart';
import 'chat_room_page.dart';
import 'new_chat_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  ChatEntity? _selectedChatForSplitView;

  @override
  void initState() {
    super.initState();
    context.read<ChatListBloc>().add(const LoadChatsEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onChatSelected(ChatEntity chat) {
    if (ResponsiveLayout.isDesktop(context) ||
        ResponsiveLayout.isTablet(context)) {
      setState(() {
        _selectedChatForSplitView = chat;
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(chat: chat),
        ),
      );
    }
  }

  void _openNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NewChatPage(),
      ),
    );
  }

  void _showUserProfileDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomAvatar(
              imageUrl: user?.photoURL,
              name: user?.displayName ?? 'You',
              radius: 40,
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'WhatsApp User',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              user?.email ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Connected with Google Account',
                style: TextStyle(
                  color: AppColors.teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isWideScreen = ResponsiveLayout.isDesktop(context) ||
        ResponsiveLayout.isTablet(context);

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 380,
              child: _buildMainView(isDark),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: _selectedChatForSplitView != null
                  ? KeyedSubtree(
                      key: ValueKey(_selectedChatForSplitView!.id),
                      child: ChatRoomPage(chat: _selectedChatForSplitView!),
                    )
                  : _buildSplitViewPlaceholder(isDark),
            ),
          ],
        ),
      );
    }

    return _buildMainView(isDark);
  }

  Widget _buildMainView(bool isDark) {
    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildStandardAppBar(isDark),
      body: _buildChatsList(),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New chat',
        onPressed: _openNewChat,
        child: const Icon(Icons.chat_rounded),
      ),
    );
  }

  PreferredSizeWidget _buildStandardAppBar(bool isDark) {
    return AppBar(
      title: const Text(
        AppStrings.appName,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          tooltip: 'Toggle Theme',
          onPressed: () {
            context.read<ThemeCubit>().toggleTheme();
          },
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search chats',
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'new_chat') {
              _openNewChat();
            } else if (value == 'profile') {
              _showUserProfileDialog(context);
            } else if (value == 'archived') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchivedChatsPage()),
              );
            } else if (value == 'theme') {
              context.read<ThemeCubit>().toggleTheme();
            } else if (value == 'logout') {
              context.read<AuthBloc>().add(SignOutEvent());
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'new_chat',
              child: Text('New chat'),
            ),
            const PopupMenuItem(
              value: 'profile',
              child: Text('Profile'),
            ),
            const PopupMenuItem(
              value: 'archived',
              child: Text('Archived chats'),
            ),
            const PopupMenuItem(
              value: 'theme',
              child: Text('Toggle Dark/Light Mode'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Text('Sign out'),
            ),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
          context.read<ChatListBloc>().add(const SearchChatsEvent(''));
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: AppStrings.searchHint,
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
        onChanged: (val) {
          context.read<ChatListBloc>().add(SearchChatsEvent(val));
        },
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              context.read<ChatListBloc>().add(const SearchChatsEvent(''));
            },
          ),
      ],
    );
  }

  Widget _buildChatsList() {
    return BlocBuilder<ChatListBloc, ChatListState>(
      builder: (context, state) {
        if (state is ChatListLoading) {
          return const ChatListSkeleton();
        }

        if (state is ChatListLoaded) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<ChatListBloc>().add(const LoadChatsEvent());
            },
            child: ListView(
              children: [
                // Archived Header Tile (if any archived chats exist)
                if (state.archivedCount > 0 && state.searchQuery.isEmpty)
                  ListTile(
                    leading: const Padding(
                      padding: EdgeInsets.only(left: 6.0),
                      child: Icon(
                        Icons.archive_outlined,
                        color: AppColors.teal,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      AppStrings.archived,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${state.archivedCount}',
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ArchivedChatsPage(),
                        ),
                      );
                    },
                  ),

                if (state.chats.isEmpty)
                  SizedBox(
                    height: 420,
                    child: EmptyStateView(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: state.searchQuery.isNotEmpty
                          ? AppStrings.noChatsFound
                          : 'No conversations yet',
                      description: state.searchQuery.isNotEmpty
                          ? 'No conversations match "${state.searchQuery}".'
                          : 'Tap the green chat button below to start a new chat with registered contacts.',
                      buttonText: state.searchQuery.isEmpty ? 'Start New Chat' : null,
                      onButtonPressed: state.searchQuery.isEmpty ? _openNewChat : null,
                    ),
                  )
                else
                  ...state.chats.map((chat) {
                    return ChatTile(
                      chat: chat,
                      onTap: () => _onChatSelected(chat),
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
                        if (_selectedChatForSplitView?.id == chat.id) {
                          setState(() {
                            _selectedChatForSplitView = null;
                          });
                        }
                        context
                            .read<ChatListBloc>()
                            .add(DeleteChatEvent(chat.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat deleted')),
                        );
                      },
                    );
                  }),
              ],
            ),
          );
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildSplitViewPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.laptop_chromebook_rounded,
              size: 100,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 20),
            Text(
              'WhatsApp for Web & Desktop',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Select a conversation on the left to start messaging.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
