import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/message_type.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import 'image_viewer_page.dart';

class ContactInfoPage extends StatefulWidget {
  final ChatEntity chat;

  const ContactInfoPage({
    super.key,
    required this.chat,
  });

  @override
  State<ContactInfoPage> createState() => _ContactInfoPageState();
}

typedef ChatMediaGalleryPage = ContactInfoPage;

class _ContactInfoPageState extends State<ContactInfoPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0C1317) : const Color(0xFFF0F2F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: isDark ? const Color(0xFF1F2C34) : AppColors.lightPrimary,
        foregroundColor: Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shared Images',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              widget.chat.name,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<MessageEntity>>(
        stream: di.sl<GetMessagesUseCase>().stream(widget.chat.id, limit: 100),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final allMessages = snapshot.data ?? [];

          // Strictly filter ONLY image messages that belong to this chat and have a mediaUrl.
          // Exclude text, audio/voice notes, video, documents, and all other types.
          final imageMessages = <MessageEntity>[];
          final seenUrls = <String>{};

          for (final msg in allMessages) {
            if (msg.chatId == widget.chat.id &&
                msg.type == MessageType.image &&
                msg.mediaUrl != null &&
                msg.mediaUrl!.trim().isNotEmpty) {
              final cleanUrl = msg.mediaUrl!.trim();
              if (seenUrls.add(cleanUrl)) {
                imageMessages.add(msg);
              }
            }
          }

          // Sort descending (newest shared images first)
          imageMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (imageMessages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No images shared yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Images shared in this chat will appear here.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemCount: imageMessages.length,
            itemBuilder: (context, index) {
              final message = imageMessages[index];
              return _buildThumbnail(context, message, imageMessages, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    MessageEntity message,
    List<MessageEntity> allImages,
    bool isDark,
  ) {
    final mediaUrl = message.mediaUrl?.trim() ?? '';
    final isDataUri = mediaUrl.startsWith('data:image/');
    final isNetwork = mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://');

    Widget imageWidget;
    if (isDataUri) {
      try {
        final commaIdx = mediaUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? mediaUrl.substring(commaIdx + 1) : mediaUrl;
        final bytes = base64Decode(base64Str);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildErrorPlaceholder(isDark),
        );
      } catch (_) {
        imageWidget = _buildErrorPlaceholder(isDark);
      }
    } else if (isNetwork) {
      imageWidget = Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: isDark ? const Color(0xFF1F2C34) : Colors.black12,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _buildErrorPlaceholder(isDark),
      );
    } else {
      imageWidget = Image.file(
        File(mediaUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildErrorPlaceholder(isDark),
      );
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewerPage(
              message: message,
              galleryMessages: allImages,
            ),
          ),
        );
      },
      child: Container(
        color: isDark ? const Color(0xFF1F2C34) : Colors.black12,
        child: imageWidget,
      ),
    );
  }

  Widget _buildErrorPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1F2C34) : Colors.black12,
      child: Center(
        child: Icon(
          Icons.broken_image_rounded,
          size: 28,
          color: isDark ? Colors.white38 : Colors.black26,
        ),
      ),
    );
  }
}
