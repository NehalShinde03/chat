import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/message_type.dart';
import 'reply_preview.dart';

class MessageInputBar extends StatefulWidget {
  final MessageEntity? replyToMessage;
  final VoidCallback onCancelReply;
  final Function(String text, MessageType type, {String? mediaUrl, int? duration})
      onSendMessage;
  final ValueChanged<bool>? onTypingChanged;

  const MessageInputBar({
    super.key,
    this.replyToMessage,
    required this.onCancelReply,
    required this.onSendMessage,
    this.onTypingChanged,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isComposing = false;
  bool _isRecordingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  Timer? _typingTimer;
  bool _isCurrentlyTyping = false;
  String? _currentRecordingPath;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final isComposing = _controller.text.trim().isNotEmpty;
      if (isComposing != _isComposing) {
        setState(() {
          _isComposing = isComposing;
        });
      }

      if (_controller.text.isNotEmpty) {
        if (!_isCurrentlyTyping) {
          _isCurrentlyTyping = true;
          widget.onTypingChanged?.call(true);
        }
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (_isCurrentlyTyping) {
            _isCurrentlyTyping = false;
            widget.onTypingChanged?.call(false);
          }
        });
      } else {
        if (_isCurrentlyTyping) {
          _isCurrentlyTyping = false;
          _typingTimer?.cancel();
          widget.onTypingChanged?.call(false);
        }
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      widget.onTypingChanged?.call(false);
    }
    _audioRecorder.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _sendTextMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      widget.onTypingChanged?.call(false);
    }
    _controller.clear();
    widget.onSendMessage(text, MessageType.text);
  }

  Future<void> _startVoiceRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record voice notes.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = filePath;

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: filePath);

      setState(() {
        _isRecordingVoice = true;
        _recordSeconds = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _recordSeconds++;
        });
      });
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      if (!mounted) return;

      final isMissingPlugin = e.toString().contains('MissingPluginException');
      final message = isMissingPlugin
          ? 'Native audio recorder not linked yet. Please perform a full restart (stop and re-run flutter run) of the app.'
          : 'Failed to start recording: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordTimer?.cancel();
    try {
      if (await _audioRecorder.isRecording()) {
        final path = await _audioRecorder.stop();
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error canceling audio recording: $e');
    }

    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _recordSeconds = 0;
        _currentRecordingPath = null;
      });
    }
  }

  Future<void> _finishVoiceRecording() async {
    _recordTimer?.cancel();
    final duration = _recordSeconds == 0 ? 1 : _recordSeconds;

    try {
      String? recordedPath;
      try {
        if (await _audioRecorder.isRecording()) {
          recordedPath = await _audioRecorder.stop();
        } else {
          recordedPath = _currentRecordingPath;
        }
      } catch (recErr) {
        debugPrint('AudioRecorder stop error: $recErr');
        recordedPath = _currentRecordingPath;
      }

      setState(() {
        _isRecordingVoice = false;
        _recordSeconds = 0;
        _currentRecordingPath = null;
      });

      if (recordedPath != null && recordedPath.isNotEmpty) {
        final recordedFile = File(recordedPath);
        if (await recordedFile.exists() && await recordedFile.length() > 0) {
          widget.onSendMessage(
            'Voice note ($duration s)',
            MessageType.audio,
            mediaUrl: recordedPath,
            duration: duration,
          );
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording was too short or empty.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _recordSeconds = 0;
          _currentRecordingPath = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete recording: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  final ImagePicker _imagePicker = ImagePicker();

  /// Persists a temporary media file to permanent app documents storage.
  /// This ensures camera photos and gallery picks are not wiped out by OS cache clearance,
  /// intent disposal, or preview delays.
  Future<String> _persistMediaFile(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return sourcePath;

      final appDir = await getApplicationDocumentsDirectory();
      final persistentDir = Directory('${appDir.path}/chat_images');
      if (!await persistentDir.exists()) {
        await persistentDir.create(recursive: true);
      }

      final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
      final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}_${sourcePath.hashCode.abs()}.$ext';
      final persistentFile = File('${persistentDir.path}/$fileName');

      final bytes = await sourceFile.readAsBytes();
      if (bytes.isNotEmpty) {
        await persistentFile.writeAsBytes(bytes, flush: true);
        return persistentFile.path;
      }
      return sourcePath;
    } catch (e) {
      debugPrint('Error persisting media file: $e');
      return sourcePath;
    }
  }

  Future<void> _openCameraCapture() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (photo == null || !mounted) {
        // User cancelled camera capture gracefully
        return;
      }

      // Immediately copy captured photo to permanent application documents directory
      // so it never disappears due to OS cache clearance or camera intent cleanup
      final persistentPath = await _persistMediaFile(photo.path);
      if (!mounted) return;

      _showImagePreviewDialog([persistentPath], title: 'Captured Photo');
    } catch (e) {
      debugPrint('Could not access camera: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not access camera: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _openImageGalleryPicker() async {
    try {
      // Pick multiple images from real system gallery
      final List<XFile> pickedImages = await _imagePicker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (pickedImages.isEmpty || !mounted) {
        // User cancelled gallery selection gracefully
        return;
      }

      final persistedPaths = <String>[];
      for (final picked in pickedImages) {
        final p = await _persistMediaFile(picked.path);
        persistedPaths.add(p);
      }
      if (!mounted) return;

      _showImagePreviewDialog(persistedPaths, title: 'Selected Images');
    } catch (e) {
      try {
        final XFile? singleImage = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 80,
        );

        if (singleImage == null || !mounted) return;

        final persistedPath = await _persistMediaFile(singleImage.path);
        if (!mounted) return;

        _showImagePreviewDialog([persistedPath], title: 'Selected Image');
      } catch (err) {
        debugPrint('Could not access gallery: $err');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access gallery: $err'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _showImagePreviewDialog(List<String> imagesToSend, {String title = 'Image Preview'}) {
    final previewList = List<String>.from(imagesToSend);
    final captionController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setPreviewState) {
            void handleDeleteImage(int index) {
              if (isSending) return;
              if (index < 0 || index >= previewList.length) return;

              final removed = previewList[index];
              setPreviewState(() {
                previewList.removeAt(index);
              });

              // Clean up un-sent local persisted file asynchronously
              try {
                final file = File(removed);
                file.exists().then((exists) {
                  if (exists) {
                    file.delete().catchError((_) => file);
                  }
                });
              } catch (_) {}

              // Close dialog immediately if no images remain
              if (previewList.isEmpty && dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            }

            return Dialog(
              backgroundColor: const Color(0xFF1F2C34),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$title (${previewList.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: isSending ? null : () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (previewList.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No images selected',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: previewList.length == 1
                            ? Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: _buildPreviewImage(previewList.first),
                                    ),
                                  ),
                                  if (!isSending)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        radius: 16,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Delete image',
                                          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                                          onPressed: () => handleDeleteImage(0),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : GridView.builder(
                                itemCount: previewList.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemBuilder: (context, idx) {
                                  final img = previewList[idx];
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _buildPreviewImage(img),
                                      ),
                                      if (!isSending)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: CircleAvatar(
                                            backgroundColor: Colors.black54,
                                            radius: 14,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              tooltip: 'Delete image',
                                              icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                              onPressed: () => handleDeleteImage(idx),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: captionController,
                      enabled: !isSending,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: (previewList.isEmpty || isSending)
                            ? null
                            : () async {
                                setPreviewState(() {
                                  isSending = true;
                                });
                                try {
                                  final caption = captionController.text.trim();
                                  for (int i = 0; i < previewList.length; i++) {
                                    final img = previewList[i];
                                    final msgText = i == 0 ? caption : '';
                                    widget.onSendMessage(
                                      msgText,
                                      MessageType.image,
                                      mediaUrl: img,
                                    );
                                  }
                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                } catch (err) {
                                  debugPrint('Failed to send images: $err');
                                  if (dialogCtx.mounted) {
                                    setPreviewState(() {
                                      isSending = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to send image: $err'),
                                        backgroundColor: AppColors.errorRed,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          isSending
                              ? 'Sending...'
                              : (previewList.isEmpty
                                  ? 'No Images'
                                  : 'Send ${previewList.length} Image${previewList.length > 1 ? "s" : ""}'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewImage(String pathOrUrl) {
    if (pathOrUrl.startsWith('data:image/')) {
      try {
        final commaIdx = pathOrUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? pathOrUrl.substring(commaIdx + 1) : pathOrUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white54),
        );
      } catch (_) {
        return const Icon(Icons.broken_image, color: Colors.white54);
      }
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white54),
      );
    }
    return Image.file(
      File(pathOrUrl),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white54),
    );
  }



  String _formatTimer(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final inputBg = isDark ? const Color(0xFF1F2C34) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyToMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ReplyPreview(
                message: widget.replyToMessage!,
                onCancel: widget.onCancelReply,
              ),
            ),

          // Main input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: _isRecordingVoice
                      ? _buildRecordingBar(isDark)
                      : _buildTextBar(isDark),
                ),
              ),
              const SizedBox(width: 6),

              Material(
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                shape: const CircleBorder(),
                elevation: 2,
                child: GestureDetector(
                  onLongPressStart: (_) {
                    if (!_isComposing && !_isRecordingVoice) {
                      _startVoiceRecording();
                    }
                  },
                  onLongPressEnd: (_) {
                    if (_isRecordingVoice) {
                      _finishVoiceRecording();
                    }
                  },
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (_isRecordingVoice) {
                        _finishVoiceRecording();
                      } else if (_isComposing) {
                        _sendTextMessage();
                      } else {
                        _startVoiceRecording();
                      }
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Icon(
                        _isRecordingVoice
                            ? Icons.send_rounded
                            : (_isComposing ? Icons.send_rounded : Icons.mic_rounded),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.fiber_manual_record,
            color: Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _formatTimer(_recordSeconds),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _cancelVoiceRecording,
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            label: const Text(
              'Cancel',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBar(bool isDark) {
    final iconColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(Icons.emoji_emotions_outlined, color: iconColor),
          onPressed: () {},
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            maxLines: 4,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: AppStrings.typeMessage,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.attach_file_rounded, color: iconColor),
          onPressed: _openImageGalleryPicker,
        ),
        if (!_isComposing)
          IconButton(
            icon: Icon(Icons.camera_alt_rounded, color: iconColor),
            onPressed: _openCameraCapture,
          ),
      ],
    );
  }
}
