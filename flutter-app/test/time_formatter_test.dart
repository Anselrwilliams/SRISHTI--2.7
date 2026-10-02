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
}
