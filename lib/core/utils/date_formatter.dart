import 'package:intl/intl.dart';

class DateFormatter {
  static String formatMessageTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime).toLowerCase();
  }

  static String formatChatListTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return DateFormat('hh:mm a').format(dateTime).toLowerCase();
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }

  static String formatDateGroupHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  static bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  static String formatLastSeen(DateTime? lastSeen, {bool isOnline = false}) {
    if (isOnline) return 'online';
    if (lastSeen == null) return 'offline';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'last seen just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return 'last seen $mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    }

    final today = DateTime(now.year, now.month, now.day);
    final seenDate = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
    final daysDiff = today.difference(seenDate).inDays;
    final timeStr = DateFormat('hh:mm a').format(lastSeen).toLowerCase();

    if (daysDiff == 0) {
      return 'last seen today at $timeStr';
    } else if (daysDiff == 1) {
      return 'last seen yesterday at $timeStr';
    } else {
      return 'last seen ${DateFormat('dd/MM/yy').format(lastSeen)} at $timeStr';
    }
  }
}
