import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ScrollToBottomFab extends StatelessWidget {
  final bool isVisible;
  final int unreadCount;
  final VoidCallback onTap;

  const ScrollToBottomFab({
    super.key,
    required this.isVisible,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedScale(
      scale: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: isDark ? const Color(0xFF233138) : Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: isVisible ? onTap : null,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.keyboard_double_arrow_down_rounded,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    size: 24,
                  ),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: -6,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.greenBadge,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
