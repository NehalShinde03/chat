import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/message_type.dart';

class ReplyPreview extends StatelessWidget {
  final MessageEntity message;
  final VoidCallback? onCancel;
  final bool isInsideBubble;

  const ReplyPreview({
    super.key,
    required this.message,
    this.onCancel,
    this.isInsideBubble = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isInsideBubble
        ? (isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.05))
        : (isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5));

    return Container(
      margin: EdgeInsets.only(
        bottom: isInsideBubble ? 6 : 0,
        top: isInsideBubble ? 2 : 0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: AppColors.teal, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.senderName,
                  style: const TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (message.type == MessageType.image) ...[
                      const Icon(Icons.image, size: 14, color: AppColors.iconMuted),
                      const SizedBox(width: 4),
                      const Text('Photo', style: TextStyle(fontSize: 12)),
                    ] else if (message.type == MessageType.audio) ...[
                      const Icon(Icons.mic, size: 14, color: AppColors.iconMuted),
                      const SizedBox(width: 4),
                      const Text('Voice message', style: TextStyle(fontSize: 12)),
                    ] else ...[
                      Expanded(
                        child: Text(
                          message.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (message.type == MessageType.image && message.mediaUrl != null) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildReplyImage(message.mediaUrl!),
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onCancel,
              child: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.iconMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyImage(String mediaUrl) {
    if (mediaUrl.startsWith('data:image/')) {
      try {
        final commaIdx = mediaUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? mediaUrl.substring(commaIdx + 1) : mediaUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 24),
        );
      } catch (_) {
        return const Icon(Icons.broken_image, size: 24);
      }
    }
    if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
      return Image.network(
        mediaUrl,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 24),
      );
    }
    return Image.file(
      File(mediaUrl),
      width: 36,
      height: 36,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 24),
    );
  }
}
