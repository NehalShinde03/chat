import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';

class DateGroupHeader extends StatelessWidget {
  final DateTime dateTime;

  const DateGroupHeader({super.key, required this.dateTime});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF182229) : const Color(0xFFE1F3FB),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          DateFormatter.formatDateGroupHeader(dateTime),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F),
          ),
        ),
      ),
    );
  }
}
