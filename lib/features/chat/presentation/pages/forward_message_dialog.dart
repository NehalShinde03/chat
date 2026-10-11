import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_avatar.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/message_entity.dart';

class ForwardMessageDialog extends StatefulWidget {
  final List<ChatEntity> chats;
  final MessageEntity message;
  final Function(List<String> selectedChatIds) onForward;

  const ForwardMessageDialog({
    super.key,
    required this.chats,
    required this.message,
    required this.onForward,
  });

  @override
  State<ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends State<ForwardMessageDialog> {
  final Set<String> _selectedChatIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 550),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Forward to...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.chats.length,
                  itemBuilder: (context, index) {
                    final chat = widget.chats[index];
                    final isSelected = _selectedChatIds.contains(chat.id);

                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: AppColors.teal,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedChatIds.add(chat.id);
                          } else {
                            _selectedChatIds.remove(chat.id);
                          }
                        });
                      },
                      secondary: CustomAvatar(
                        name: chat.name,
                        imageUrl: chat.avatarUrl,
                        radius: 20,
                      ),
                      title: Text(
                        chat.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _selectedChatIds.isEmpty
                          ? null
                          : () {
                              widget.onForward(_selectedChatIds.toList());
                              Navigator.pop(context);
                            },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text('Forward (${_selectedChatIds.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
