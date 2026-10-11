import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/custom_avatar.dart';
import '../../domain/entities/chat_entity.dart';

class ChatTile extends StatelessWidget {
  final ChatEntity chat;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleArchive;
  final VoidCallback onMarkAsRead;
  final VoidCallback? onDelete;

  const ChatTile({
    super.key,
    required this.chat,
    required this.onTap,
    required this.onTogglePin,
    required this.onToggleArchive,
    required this.onMarkAsRead,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CustomAvatar(
              name: chat.name,
              imageUrl: chat.avatarUrl,
              radius: 26,
              showOnlineIndicator: true,
              isOnline: chat.isOnline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Last Message Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormatter.formatChatListTime(chat.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: chat.unreadCount > 0
                              ? AppColors.greenBadge
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                          fontWeight: chat.unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Last message preview & unread badge / pin
                  Row(
                    children: [
                      Expanded(
                        child: chat.isTyping
                            ? const Text(
                                'typing...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.teal,
                                ),
                              )
                            : Text(
                                chat.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      if (chat.isPinned)
                        Icon(
                          Icons.push_pin_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      if (chat.isPinned && chat.unreadCount > 0)
                        const SizedBox(width: 6),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.greenBadge,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat.unreadCount > 99
                                ? '99+'
                                : '${chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
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
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(chat.isPinned ? 'Unpin chat' : 'Pin chat'),
                onTap: () {
                  Navigator.pop(ctx);
                  onTogglePin();
                },
              ),
              ListTile(
                leading: Icon(
                  chat.isArchived ? Icons.unarchive : Icons.archive_outlined,
                ),
                title: Text(chat.isArchived ? 'Unarchive chat' : 'Archive chat'),
                onTap: () {
                  Navigator.pop(ctx);
                  onToggleArchive();
                },
              ),
              if (chat.unreadCount > 0)
                ListTile(
                  leading: const Icon(Icons.mark_chat_read_outlined),
                  title: const Text('Mark as read'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onMarkAsRead();
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Delete chat', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: Text('Messages in the conversation with "${chat.name}" will be deleted from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete chat'),
          ),
        ],
      ),
    );
  }
}
