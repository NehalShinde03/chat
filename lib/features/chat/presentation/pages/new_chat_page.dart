import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/widgets/custom_avatar.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/usecases/get_or_create_conversation_usecase.dart';
import '../../domain/usecases/get_registered_users_usecase.dart';
import 'chat_room_page.dart';

class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final TextEditingController _searchController = TextEditingController();
  final GetRegisteredUsersUseCase _getRegisteredUsersUseCase =
      di.sl<GetRegisteredUsersUseCase>();
  final GetOrCreateConversationUseCase _getOrCreateConversationUseCase =
      di.sl<GetOrCreateConversationUseCase>();

  List<UserEntity> _allUsers = [];
  List<UserEntity> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final users = await _getRegisteredUsersUseCase();
      final filteredList = users.where((u) => u.id != currentUid).toList();
      if (!mounted) return;
      setState(() {
        _allUsers = filteredList;
        _filteredUsers = filteredList;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((u) {
          return u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _onUserSelected(UserEntity user) async {
    try {
      final chat = await _getOrCreateConversationUseCase(user);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(chat: chat),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open chat: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildStandardAppBar(isDark),
      body: _buildBody(isDark),
    );
  }

  PreferredSizeWidget _buildStandardAppBar(bool isDark) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select contact',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (!_isLoading && _errorMessage == null)
            Text(
              '${_allUsers.length} ${_allUsers.length == 1 ? 'contact' : 'contacts'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search contacts',
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: _loadUsers,
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
            _filteredUsers = _allUsers;
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search by name or email...',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
        onChanged: _onSearchChanged,
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SkeletonLoader(width: 48, height: 48, borderRadius: 24),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: 140, height: 16),
                    SizedBox(height: 8),
                    SkeletonLoader(width: 200, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: _loadUsers,
      );
    }

    if (_filteredUsers.isEmpty) {
      if (_isSearching && _searchController.text.isNotEmpty) {
        return const EmptyStateView(
          icon: Icons.search_off_rounded,
          title: 'No contacts found',
          description: 'Try searching with a different name or email address.',
        );
      }
      return const EmptyStateView(
        icon: Icons.person_search_rounded,
        title: 'No other users registered yet',
        description:
            'When other users sign in to WhatsApp with Google, their profiles will appear here automatically.',
      );
    }

    return ListView.builder(
      itemCount: _filteredUsers.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final subtitleText = user.email.isNotEmpty
            ? user.email
            : (user.statusMessage != null && user.statusMessage!.isNotEmpty
                ? user.statusMessage!
                : 'Hey there! I am using WhatsApp.');

        return ListTile(
          leading: CustomAvatar(
            imageUrl: user.avatarUrl,
            name: user.name,
            radius: 24,
            showOnlineIndicator: false,
          ),
          title: Text(
            user.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            subtitleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          onTap: () => _onUserSelected(user),
        );
      },
    );
  }
}
