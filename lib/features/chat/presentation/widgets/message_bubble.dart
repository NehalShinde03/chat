import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/message_type.dart';
import '../pages/image_viewer_page.dart';
import 'reply_preview.dart';
import 'swipe_to_reply_wrapper.dart';
import 'voice_message_player.dart';

class MessageBubble extends StatelessWidget {
  static final Map<String, Uint8List> _base64Cache = {};

  final MessageEntity message;
  final bool isOutgoing;
  final VoidCallback onSwipeReply;
  final VoidCallback onForward;
  final VoidCallback? onDelete;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isGroupChat;
  final List<MessageEntity>? galleryMessages;
  final void Function(MessageEntity)? onForwardMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOutgoing,
    required this.onSwipeReply,
    required this.onForward,
    this.onDelete,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.isGroupChat = false,
    this.galleryMessages,
    this.onForwardMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = isOutgoing
        ? (isDark ? AppColors.darkOutgoingBubble : AppColors.lightOutgoingBubble)
        : (isDark ? AppColors.darkIncomingBubble : AppColors.lightIncomingBubble);

    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    // WhatsApp-style corner rounding based on message grouping:
    final Radius radiusTopLeft;
    final Radius radiusTopRight;
    final Radius radiusBottomLeft;
    final Radius radiusBottomRight;

    if (isOutgoing) {
      // Outgoing messages (right-aligned):
      radiusTopLeft = const Radius.circular(14);
      radiusBottomLeft = const Radius.circular(14);
      // Sharp nip (2px) only on first message of a group, smooth 4px on subsequent
      radiusTopRight = Radius.circular(isFirstInGroup ? 2 : 5);
      // Fully rounded 14px on the last message of group, smooth 4px on middle
      radiusBottomRight = Radius.circular(isLastInGroup ? 14 : 5);
    } else {
      // Incoming messages (left-aligned):
      radiusTopRight = const Radius.circular(14);
      radiusBottomRight = const Radius.circular(14);
      // Sharp nip (2px) only on first message of a group, smooth 4px on subsequent
      radiusTopLeft = Radius.circular(isFirstInGroup ? 2 : 5);
      // Fully rounded 14px on the last message of group, smooth 4px on middle
      radiusBottomLeft = Radius.circular(isLastInGroup ? 14 : 5);
    }

    return SwipeToReplyWrapper(
      onReply: onSwipeReply,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        onLongPress: () => _showBubbleMenu(context),
        child: Align(
          alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            margin: EdgeInsets.only(
              left: 12,
              right: 12,
              top: isFirstInGroup ? 6.0 : 1.5,
              bottom: isLastInGroup ? 6.0 : 1.5,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: message.type == MessageType.image ? 4 : 10,
              vertical: message.type == MessageType.image ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: radiusTopLeft,
                topRight: radiusTopRight,
                bottomLeft: radiusBottomLeft,
                bottomRight: radiusBottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender Name for group chats (incoming and first in group)
                if (isGroupChat && !isOutgoing && isFirstInGroup)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2, top: 2),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.teal,
                      ),
                    ),
                  ),

                // Forwarded Tag
                if (message.isForwarded)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 4, top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forward_rounded,
                          size: 13,
                          color: AppColors.iconMuted,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Forwarded',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.iconMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Quoted / Replied message preview
                if (message.replyToMessage != null)
                  ReplyPreview(
                    message: message.replyToMessage!,
                    isInsideBubble: true,
                  ),

                // Message Content by Type
                if (message.type == MessageType.image &&
                    message.mediaUrl != null)
                  _buildImageContent(context),
                if (message.type == MessageType.audio)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: VoiceMessagePlayer(
                      messageId: message.id,
                      mediaUrl: message.mediaUrl,
                      durationSeconds: message.audioDurationSeconds ?? 15,
                      isOutgoing: isOutgoing,
                    ),
                  ),
                if (message.type == MessageType.text ||
                    (message.type == MessageType.image &&
                        message.text.isNotEmpty))
                  Padding(
                    padding: EdgeInsets.only(
                      left: 4,
                      right: 4,
                      top: message.type == MessageType.image ? 6 : 0,
                      bottom: 2,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            fontSize: 15,
                            color: textColor,
                            height: 1.3,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormatter.formatMessageTime(message.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              if (isOutgoing) ...[
                                const SizedBox(width: 4),
                                _buildStatusIcon(message.status),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Timestamp and Delivery Status Tick for non-text messages (e.g. image without caption)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 2, top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormatter.formatMessageTime(message.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          if (isOutgoing) ...[
                            const SizedBox(width: 4),
                            _buildStatusIcon(message.status),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final mediaUrl = message.mediaUrl ?? '';
    final isNetwork = mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://');
    final isDataUri = mediaUrl.startsWith('data:image/');

    Widget imageWidget;
    if (isDataUri) {
      try {
        Uint8List? bytes = _base64Cache[message.id];
        if (bytes == null) {
          final commaIdx = mediaUrl.indexOf(',');
          final base64Str = commaIdx != -1 ? mediaUrl.substring(commaIdx + 1) : mediaUrl;
          bytes = base64Decode(base64Str);
          _base64Cache[message.id] = bytes;
        }
        imageWidget = Image.memory(
          bytes,
          key: ValueKey('img_mem_${message.id}'),
          gaplessPlayback: true,
          cacheWidth: 800,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: 140,
            color: Colors.black12,
            child: const Center(child: Icon(Icons.broken_image)),
          ),
        );
      } catch (_) {
        imageWidget = Container(
          height: 140,
          color: Colors.black12,
          child: const Center(child: Icon(Icons.broken_image)),
        );
      }
    } else if (isNetwork) {
      imageWidget = Image.network(
        mediaUrl,
        key: ValueKey('img_net_${message.id}'),
        gaplessPlayback: true,
        cacheWidth: 800,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          height: 140,
          color: Colors.black12,
          child: const Center(child: Icon(Icons.broken_image)),
        ),
      );
    } else {
      imageWidget = Image.file(
        File(mediaUrl),
        key: ValueKey('img_file_${message.id}'),
        gaplessPlayback: true,
        cacheWidth: 800,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          height: 140,
          color: Colors.black12,
          child: const Center(child: Icon(Icons.broken_image)),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewerPage(
              message: message,
              galleryMessages: galleryMessages,
              onForward: onForward,
              onForwardMessage: onForwardMessage,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Hero(
          tag: 'image_${message.id}',
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(
          Icons.access_time_rounded,
          size: 13,
          color: AppColors.iconMuted,
        );
      case MessageStatus.sent:
        return const Icon(
          Icons.check,
          size: 15,
          color: AppColors.iconMuted,
        );
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all,
          size: 15,
          color: AppColors.iconMuted,
        );
      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 15,
          color: AppColors.blueCheck,
        );
    }
  }

  void _showBubbleMenu(BuildContext context) {
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
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  onSwipeReply();
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward_rounded),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.pop(ctx);
                  onForward();
                },
              ),
              if (message.text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy Text'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied')),
                    );
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        title: const Text('Delete Message?'),
        content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
