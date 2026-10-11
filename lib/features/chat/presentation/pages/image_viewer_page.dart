import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/message_entity.dart';

class ImageViewerPage extends StatefulWidget {
  final MessageEntity message;
  final List<MessageEntity>? galleryMessages;
  final VoidCallback? onForward;
  final void Function(MessageEntity)? onForwardMessage;

  const ImageViewerPage({
    super.key,
    required this.message,
    this.galleryMessages,
    this.onForward,
    this.onForwardMessage,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late PageController _pageController;
  late List<MessageEntity> _images;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    if (widget.galleryMessages != null && widget.galleryMessages!.isNotEmpty) {
      _images = widget.galleryMessages!;
    } else {
      _images = [widget.message];
    }

    final initialIdx = _images.indexWhere((m) => m.id == widget.message.id);
    _currentIndex = initialIdx != -1 ? initialIdx : 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMsg = _images[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _images.length > 1
                  ? '${currentMsg.senderName} (${_currentIndex + 1}/${_images.length})'
                  : currentMsg.senderName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormatter.formatMessageTime(currentMsg.timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forward_rounded),
            tooltip: 'Forward',
            onPressed: () {
              if (widget.onForwardMessage != null) {
                widget.onForwardMessage!(currentMsg);
              } else if (widget.onForward != null) {
                widget.onForward!();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing photo...')),
              );
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = _images[index];
          final mediaUrl = item.mediaUrl ?? '';
          final isNetwork = mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://');
          final isDataUri = mediaUrl.startsWith('data:image/');

          Widget displayImage;
          if (isDataUri) {
            try {
              final commaIdx = mediaUrl.indexOf(',');
              final base64Str = commaIdx != -1 ? mediaUrl.substring(commaIdx + 1) : mediaUrl;
              final bytes = base64Decode(base64Str);
              displayImage = Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 64, color: Colors.white54),
                    SizedBox(height: 12),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              );
            } catch (_) {
              displayImage = const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.white54),
                  SizedBox(height: 12),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              );
            }
          } else if (isNetwork) {
            displayImage = Image.network(
              mediaUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (_, _, _) => const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.white54),
                  SizedBox(height: 12),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            );
          } else {
            displayImage = Image.file(
              File(mediaUrl),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.white54),
                  SizedBox(height: 12),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: Hero(
              tag: 'image_${item.id}',
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: displayImage,
              ),
            ),
          );
        },
      ),
    );
  }
}
