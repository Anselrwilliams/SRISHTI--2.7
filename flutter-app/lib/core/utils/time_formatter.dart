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
}
