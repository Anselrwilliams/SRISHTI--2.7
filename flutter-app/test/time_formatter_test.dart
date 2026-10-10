import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/core/utils/time_formatter.dart';

void main() {
  group('TimeFormatter - 12-Hour AM/PM Specification Tests', () {
    test('Converts prompt examples correctly', () {
      // CURRENT EXAMPLE in prompt:
      expect(
        TimeFormatter.formatTime('13:00:00 - 15:00:00'),
        equals('1:00 PM - 3:00 PM'),
      );

      // OTHER EXAMPLES in prompt:
      expect(
        TimeFormatter.formatTime('10:00:00 - 12:00:00'),
        equals('10:00 AM - 12:00 PM'),
      );
      expect(
        TimeFormatter.formatTime('14:00:00 - 16:00:00'),
        equals('2:00 PM - 4:00 PM'),
      );
      expect(
        TimeFormatter.formatTime('09:30:00 - 11:30:00'),
        equals('9:30 AM - 11:30 AM'),
      );
    });

    test('Converts individual 24-hour time strings to h:mm a format without seconds', () {
      expect(TimeFormatter.formatTime('13:00:00'), equals('1:00 PM'));
      expect(TimeFormatter.formatTime('10:00:00'), equals('10:00 AM'));
      expect(TimeFormatter.formatTime('14:00:00'), equals('2:00 PM'));
      expect(TimeFormatter.formatTime('09:30:00'), equals('9:30 AM'));
      expect(TimeFormatter.formatTime('15:45:00'), equals('3:45 PM'));
      expect(TimeFormatter.formatTime('23:59:59'), equals('11:59 PM'));
      expect(TimeFormatter.formatTime('08:05:00'), equals('8:05 AM'));
    });

    test('Ensures noon is 12:00 PM and midnight is 12:00 AM', () {
      expect(TimeFormatter.formatTime('12:00:00'), equals('12:00 PM'));
      expect(TimeFormatter.formatTime('12:30:00'), equals('12:30 PM'));
      expect(TimeFormatter.formatTime('00:00:00'), equals('12:00 AM'));
      expect(TimeFormatter.formatTime('00:15:00'), equals('12:15 AM'));
    });

    test('Supports strings without seconds (HH:mm)', () {
      expect(TimeFormatter.formatTime('13:00'), equals('1:00 PM'));
      expect(TimeFormatter.formatTime('09:30'), equals('9:30 AM'));
      expect(TimeFormatter.formatTime('12:00'), equals('12:00 PM'));
      expect(TimeFormatter.formatTime('00:00'), equals('12:00 AM'));
      expect(TimeFormatter.formatTime('14:00 - 16:00'), equals('2:00 PM - 4:00 PM'));
    });

    test('Normalizes existing 12-hour strings to h:mm a format', () {
      expect(TimeFormatter.formatTime('1:00 PM'), equals('1:00 PM'));
      expect(TimeFormatter.formatTime('10:00 AM'), equals('10:00 AM'));
      expect(TimeFormatter.formatTime('09:30 AM'), equals('9:30 AM'));
      expect(TimeFormatter.formatTime('02:00 PM'), equals('2:00 PM'));
      expect(TimeFormatter.formatTime('12:00 PM'), equals('12:00 PM'));
      expect(TimeFormatter.formatTime('12:00 AM'), equals('12:00 AM'));
    });

    test('formatTimeRange combines start and end times cleanly', () {
      expect(
        TimeFormatter.formatTimeRange('13:00:00', '15:00:00'),
        equals('1:00 PM - 3:00 PM'),
      );
      expect(
        TimeFormatter.formatTimeRange('10:00:00', '12:00:00'),
        equals('10:00 AM - 12:00 PM'),
      );
      expect(
        TimeFormatter.formatTimeRange('10:00:00', null),
        equals('10:00 AM'),
      );
      expect(
        TimeFormatter.formatTimeRange(null, '15:00:00'),
        equals('3:00 PM'),
      );
      expect(
        TimeFormatter.formatTimeRange(null, null, fallback: '13:00:00 - 15:00:00'),
        equals('1:00 PM - 3:00 PM'),
      );
      expect(
        TimeFormatter.formatTimeRange(null, null, fallback: '10:00 AM'),
        equals('10:00 AM'),
      );
    });

    test('formatDateTime formats DateTime instances to h:mm a', () {
      expect(
        TimeFormatter.formatDateTime(DateTime(2026, 10, 1, 13, 0)),
        equals('1:00 PM'),
      );
      expect(
        TimeFormatter.formatDateTime(DateTime(2026, 10, 1, 12, 0)),
        equals('12:00 PM'),
      );
      expect(
        TimeFormatter.formatDateTime(DateTime(2026, 10, 1, 0, 0)),
        equals('12:00 AM'),
      );
      expect(
        TimeFormatter.formatDateTime(DateTime(2026, 10, 1, 9, 30)),
        equals('9:30 AM'),
      );
    });

    test('Preserves non-time fallback strings and handles edge cases', () {
      expect(TimeFormatter.formatTime('Day 1'), equals('Day 1'));
      expect(TimeFormatter.formatTime('TBD'), equals('TBD'));
      expect(TimeFormatter.formatTime(''), equals(''));
      expect(TimeFormatter.formatTime(null), equals(''));
    });
  });

  group('TimeFormatter - Local Timezone & Safe Parsing Tests', () {
    test('parseToLocal parses ISO-8601 UTC and converts to local DateTime', () {
      final utcIso = '2026-10-10T04:30:00Z';
      final parsed = TimeFormatter.parseToLocal(utcIso);
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse);
      // Verify point in time is preserved
      expect(parsed.toUtc(), equals(DateTime.utc(2026, 10, 10, 4, 30)));
    });

    test('parseToLocal handles DateTime object input', () {
      final dtUtc = DateTime.utc(2026, 10, 10, 12, 0);
      final parsed = TimeFormatter.parseToLocal(dtUtc);
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse);
      expect(parsed.toUtc(), equals(dtUtc));
    });

    test('parseToLocal returns null for null, empty, or unparseable strings', () {
      expect(TimeFormatter.parseToLocal(null), isNull);
      expect(TimeFormatter.parseToLocal(''), isNull);
      expect(TimeFormatter.parseToLocal('   '), isNull);
      expect(TimeFormatter.parseToLocal('invalid-date'), isNull);
    });
  });

  group('TimeFormatter - Relative Time & Dynamic Labels Tests', () {
    final fixedNow = DateTime(2026, 10, 10, 15, 0, 0);

    test('Returns "Time unavailable" fallback for null or invalid timestamps', () {
      expect(TimeFormatter.formatRelativeTime(null, now: fixedNow), equals('Time unavailable'));
      expect(TimeFormatter.formatRelativeTime('invalid-string', now: fixedNow), equals('Time unavailable'));
      expect(TimeFormatter.formatRelativeTime(null, now: fixedNow, fallback: 'N/A'), equals('N/A'));
    });

    test('Returns "Just now" for arrivals within the last 60 seconds or slight future drift', () {
      // 10 seconds ago
      final tenSecAgo = fixedNow.subtract(const Duration(seconds: 10));
      expect(TimeFormatter.formatRelativeTime(tenSecAgo, now: fixedNow), equals('Just now'));

      // 50 seconds ago
      final fiftySecAgo = fixedNow.subtract(const Duration(seconds: 50));
      expect(TimeFormatter.formatRelativeTime(fiftySecAgo, now: fixedNow), equals('Just now'));

      // Slight future (e.g. 15s ahead due to clock sync)
      final future15s = fixedNow.add(const Duration(seconds: 15));
      expect(TimeFormatter.formatRelativeTime(future15s, now: fixedNow), equals('Just now'));
    });

    test('Returns "1 min ago" and "X min ago" for arrivals under 60 minutes', () {
      final oneMinAgo = fixedNow.subtract(const Duration(minutes: 1));
      expect(TimeFormatter.formatRelativeTime(oneMinAgo, now: fixedNow), equals('1 min ago'));

      final fiveMinAgo = fixedNow.subtract(const Duration(minutes: 5));
      expect(TimeFormatter.formatRelativeTime(fiveMinAgo, now: fixedNow), equals('5 min ago'));

      final fortyFiveMinAgo = fixedNow.subtract(const Duration(minutes: 45));
      expect(TimeFormatter.formatRelativeTime(fortyFiveMinAgo, now: fixedNow), equals('45 min ago'));
    });

    test('Returns "1 hour ago" and "X hours ago" for arrivals on the same calendar day', () {
      final oneHourAgo = fixedNow.subtract(const Duration(hours: 1));
      expect(TimeFormatter.formatRelativeTime(oneHourAgo, now: fixedNow), equals('1 hour ago'));

      final twoHoursAgo = fixedNow.subtract(const Duration(hours: 2));
      expect(TimeFormatter.formatRelativeTime(twoHoursAgo, now: fixedNow), equals('2 hours ago'));

      // 5 hours ago on same day
      final fiveHoursAgo = fixedNow.subtract(const Duration(hours: 5));
      expect(TimeFormatter.formatRelativeTime(fiveHoursAgo, now: fixedNow), equals('5 hours ago'));
    });

    test('Returns "Yesterday" for arrivals on the previous calendar day', () {
      // Arrival yesterday at 18:00 (21 hours prior to today 15:00)
      // This directly resolves the legacy UI "21h ago" bug: calendar yesterday correctly reports "Yesterday"
      final yesterdayArrival = DateTime(2026, 10, 9, 18, 0, 0);
      expect(TimeFormatter.formatRelativeTime(yesterdayArrival, now: fixedNow), equals('Yesterday'));

      // Yesterday morning
      final yesterdayMorning = DateTime(2026, 10, 9, 9, 30, 0);
      expect(TimeFormatter.formatRelativeTime(yesterdayMorning, now: fixedNow), equals('Yesterday'));
    });

    test('Returns "d MMM" for older arrivals beyond yesterday', () {
      final twoDaysAgo = DateTime(2026, 10, 8, 11, 0, 0);
      expect(TimeFormatter.formatRelativeTime(twoDaysAgo, now: fixedNow), equals('8 Oct'));

      final fiveDaysAgo = DateTime(2026, 10, 5, 14, 0, 0);
      expect(TimeFormatter.formatRelativeTime(fiveDaysAgo, now: fixedNow), equals('5 Oct'));
    });

    test('formatExactTime formats local check-in time accurately', () {
      final dt = DateTime(2026, 10, 10, 10, 30);
      expect(TimeFormatter.formatExactTime(dt), equals('10:30 AM'));

      final dtPm = DateTime(2026, 10, 10, 16, 45);
      expect(TimeFormatter.formatExactTime(dtPm), equals('4:45 PM'));

      expect(TimeFormatter.formatExactTime(null), equals(''));
    });

    test('formatCheckinDisplay formats combined relative and exact times cleanly', () {
      final fiveMinAgo = fixedNow.subtract(const Duration(minutes: 5));
      expect(
        TimeFormatter.formatCheckinDisplay(fiveMinAgo, now: fixedNow),
        equals('5 min ago • 2:55 PM'),
      );

      final yesterday = DateTime(2026, 10, 9, 16, 15);
      expect(
        TimeFormatter.formatCheckinDisplay(yesterday, now: fixedNow),
        equals('Yesterday • 4:15 PM'),
      );

      expect(
        TimeFormatter.formatCheckinDisplay(null, now: fixedNow),
        equals('Time unavailable'),
      );
    });
  });
}
