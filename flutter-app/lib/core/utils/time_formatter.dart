/// Centralized utility for formatting event times to 12-hour AM/PM format (h:mm a).
///
/// Features:
/// - Converts 24-hour time strings (e.g. `13:00:00`, `13:00`) to 12-hour format (`1:00 PM`).
/// - Converts ranges (e.g. `13:00:00 - 15:00:00`) to `1:00 PM - 3:00 PM`.
/// - Normalizes existing 12-hour strings (e.g. `09:30 AM` -> `9:30 AM`, `10:00:00 AM` -> `10:00 AM`).
/// - Displays noon as `12:00 PM` and midnight as `12:00 AM`.
/// - Excludes seconds completely.
/// - Preserves non-time fallback labels like `Day 1` or `TBD`.
class TimeFormatter {
  TimeFormatter._();

  /// Formats an hour (0..23) and minute (0..59) into `h:mm a` format.
  ///
  /// Examples:
  /// - (13, 0) -> '1:00 PM'
  /// - (0, 0) -> '12:00 AM'
  /// - (12, 0) -> '12:00 PM'
  /// - (9, 30) -> '9:30 AM'
  static String formatHourMinute(int hour, int minute) {
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    final displayPeriod = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:$displayMinute $displayPeriod';
  }

  /// Formats a [DateTime] instance into `h:mm a` format.
  static String formatDateTime(DateTime dt) {
    return formatHourMinute(dt.hour, dt.minute);
  }

  /// Formats a time string or range into 12-hour `h:mm a` format.
  ///
  /// Supported formats:
  /// - `13:00:00` -> `1:00 PM`
  /// - `13:00:00 - 15:00:00` -> `1:00 PM - 3:00 PM`
  /// - `10:00:00 - 12:00:00` -> `10:00 AM - 12:00 PM`
  /// - `14:00:00 - 16:00:00` -> `2:00 PM - 4:00 PM`
  /// - `09:30:00 - 11:30:00` -> `9:30 AM - 11:30 AM`
  /// - `09:30 AM` -> `9:30 AM`
  /// - `10:00 AM` -> `10:00 AM`
  /// - `12:00:00` -> `12:00 PM`
  /// - `00:00:00` -> `12:00 AM`
  static String formatTime(String? timeStr) {
    if (timeStr == null) return '';
    final trimmed = timeStr.trim();
    if (trimmed.isEmpty) return '';

    // Check if it's a range containing ' - '
    if (trimmed.contains(' - ')) {
      final parts = trimmed.split(' - ');
      if (parts.length == 2) {
        final start = formatTime(parts[0]);
        final end = formatTime(parts[1]);
        if (start.isNotEmpty && end.isNotEmpty) {
          return '$start - $end';
        } else if (start.isNotEmpty) {
          return start;
        } else if (end.isNotEmpty) {
          return end;
        }
      }
    }

    // Check if string already contains AM/PM
    final amPmMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (amPmMatch != null) {
      int hour = int.tryParse(amPmMatch.group(1)!) ?? 0;
      final minute = int.tryParse(amPmMatch.group(2)!) ?? 0;
      final period = amPmMatch.group(3)!.toUpperCase();

      if (period == 'PM' && hour < 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      return formatHourMinute(hour, minute);
    }

    // Check standard 24-hour time e.g. 13:00:00 or 13:00
    final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(trimmed);
    if (timeMatch != null) {
      final hour = int.tryParse(timeMatch.group(1)!);
      final minute = int.tryParse(timeMatch.group(2)!);
      if (hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        return formatHourMinute(hour, minute);
      }
    }

    // Fallback if not a time pattern (e.g. 'Day 1', 'TBD', etc.)
    return trimmed;
  }

  /// Formats separate start and end times into a combined 12-hour range.
  ///
  /// Examples:
  /// - ('13:00:00', '15:00:00') -> '1:00 PM - 3:00 PM'
  /// - ('10:00:00', '12:00:00') -> '10:00 AM - 12:00 PM'
  /// - ('10:00:00', null) -> '10:00 AM'
  static String formatTimeRange(
    String? start,
    String? end, {
    String? fallback,
  }) {
    final formattedStart = formatTime(start);
    final formattedEnd = formatTime(end);

    if (formattedStart.isNotEmpty && formattedEnd.isNotEmpty) {
      return '$formattedStart - $formattedEnd';
    } else if (formattedStart.isNotEmpty) {
      return formattedStart;
    } else if (formattedEnd.isNotEmpty) {
      return formattedEnd;
    }

    if (fallback != null && fallback.trim().isNotEmpty) {
      return formatTime(fallback);
    }

    return '';
  }

  /// Convenience alias for [formatTime].
  static String formatTimeOrRange(String? input) {
    return formatTime(input);
  }

  /// Parses any timestamp representation (DateTime, ISO-8601 String, etc.)
  /// into the device's local timezone.
  ///
  /// Returns `null` if the input is null, empty, or cannot be parsed.
  /// Preserves timezone information from the database (e.g. UTC ISO-8601) and
  /// reliably converts it to the device's local timezone via `.toLocal()`.
  /// Does NOT interpret naive local strings as UTC.
  static DateTime? parseToLocal(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) {
      return input.toLocal();
    }
    if (input is String) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) return null;
      try {
        final parsed = DateTime.tryParse(trimmed);
        return parsed?.toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Formats a check-in timestamp into human-friendly relative time:
  /// - `Just now` (< 1 min, or slight future clock drift)
  /// - `1 min ago` / `X min ago` (< 60 min)
  /// - `1 hour ago` / `X hours ago` (on the same calendar day)
  /// - `Yesterday` (on the previous calendar day)
  /// - `d MMM` (e.g. `10 Oct`) for older arrivals
  /// - `Time unavailable` if the timestamp is missing, null, or invalid.
  static String formatRelativeTime(
    dynamic timestamp, {
    DateTime? now,
    String fallback = 'Time unavailable',
  }) {
    final localDt = parseToLocal(timestamp);
    if (localDt == null) return fallback;

    final current = (now ?? DateTime.now()).toLocal();
    final difference = current.difference(localDt);

    // Minor future clock skew (up to 60 seconds) -> 'Just now'
    if (difference.isNegative) {
      if (difference.inSeconds.abs() <= 60) {
        return 'Just now';
      }
      return formatDateTime(localDt);
    }

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return mins == 1 ? '1 min ago' : '$mins min ago';
    }

    final isSameDay = current.year == localDt.year &&
        current.month == localDt.month &&
        current.day == localDt.day;

    if (isSameDay) {
      final hours = difference.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    }

    // Check calendar yesterday
    final yesterday = current.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == localDt.year &&
        yesterday.month == localDt.month &&
        yesterday.day == localDt.day;

    if (isYesterday) {
      return 'Yesterday';
    }

    // Older arrivals
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${localDt.day} ${months[localDt.month - 1]}';
  }

  /// Formats exact local check-in time into `h:mm a` format (e.g. `10:30 AM`).
  /// Returns empty string if the timestamp is null or invalid.
  static String formatExactTime(dynamic timestamp) {
    final localDt = parseToLocal(timestamp);
    if (localDt == null) return '';
    return formatDateTime(localDt);
  }

  /// Formats check-in display combining relative time and optional exact local time.
  /// For instance: `Yesterday • 4:15 PM` or `5 min ago • 10:30 AM`.
  static String formatCheckinDisplay(
    dynamic timestamp, {
    DateTime? now,
    bool includeExact = true,
  }) {
    final relative = formatRelativeTime(timestamp, now: now);
    if (relative == 'Time unavailable') return relative;
    if (!includeExact) return relative;

    final exact = formatExactTime(timestamp);
    if (exact.isEmpty || relative == 'Just now') return relative;

    return '$relative • $exact';
  }
}
