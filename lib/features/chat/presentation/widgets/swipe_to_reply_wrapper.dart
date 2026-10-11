import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const SwipeToReplyWrapper({
    super.key,
    required this.child,
    required this.onReply,
  });

  @override
  State<SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  static const double _triggerThreshold = 55.0;
  static const double _maxDrag = 70.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0 || _dragOffset > 0) {
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, _maxDrag);
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset >= _triggerThreshold) {
          widget.onReply();
        }
        setState(() {
          _dragOffset = 0.0;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          _dragOffset = 0.0;
        });
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Animated Reply Icon behind
          if (_dragOffset > 5)
            Positioned(
              left: (_dragOffset * 0.4).clamp(8.0, 32.0),
              child: Opacity(
                opacity: (_dragOffset / _triggerThreshold).clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.reply_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

          // Sliding message child
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
