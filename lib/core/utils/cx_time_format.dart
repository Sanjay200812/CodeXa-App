/// Canonical relative and localized time formatters for CodeXa
class CxTimeFormat {
  CxTimeFormat._();

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Instagram-style story publication relative time
  /// Examples: "Just now", "5m ago", "30m ago", "2h ago", "23h ago"
  static String formatStoryTime(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final dt = dateTime.isUtc ? dateTime : dateTime.toUtc();
    final diff = now.difference(dt);

    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '23h ago';
    }
  }

  /// Story Activity viewer relative timestamp
  /// Examples: "Viewed just now", "Viewed 5m ago", "Viewed 2h ago", "Viewed Yesterday"
  static String formatViewerTime(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final dt = dateTime.isUtc ? dateTime : dateTime.toUtc();
    final diff = now.difference(dt);

    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Viewed just now';
    } else if (diff.inMinutes < 60) {
      return 'Viewed ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Viewed ${diff.inHours}h ago';
    } else if (diff.inHours < 48) {
      return 'Viewed Yesterday';
    } else {
      return 'Viewed ${diff.inDays}d ago';
    }
  }

  /// WhatsApp-style conversation date separator
  /// Examples: "Today", "Yesterday", "10 October 2026"
  static String formatChatDateSeparator(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(local.year, local.month, local.day);

    final diffDays = today.difference(msgDate).inDays;
    if (diffDays == 0) {
      return 'Today';
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else {
      final monthName = (local.month >= 1 && local.month <= 12)
          ? _months[local.month - 1]
          : '${local.month}';
      return '${local.day} $monthName ${local.year}';
    }
  }

  /// WhatsApp-style compact message send time
  /// Examples: "10:32 AM", "11:05 PM"
  static String formatMessageTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Conversation list relative timestamp
  /// Examples: "Just now", "1m", "5m", "1h", "5h", "Yesterday", "10/10/2026"
  static String formatChatListRelative(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final dt = dateTime.isUtc ? dateTime : dateTime.toUtc();
    final diff = now.difference(dt);

    if (diff.isNegative || diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inHours < 48) {
      return 'Yesterday';
    } else {
      final local = dateTime.toLocal();
      return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    }
  }
}
