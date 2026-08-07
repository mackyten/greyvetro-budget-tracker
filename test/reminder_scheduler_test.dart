import 'package:flutter_test/flutter_test.dart';

import 'package:vetro_ledger/features/net_worth/data/reminder_scheduler.dart';
import 'package:vetro_ledger/features/net_worth/models/monthly_entry.dart';

void main() {
  final scheduler = ReminderScheduler.instance;

  group('shouldRemind', () {
    test('false when the current month is already logged', () {
      final now = DateTime(2026, 1, 28);
      final entries = [MonthlyEntry(month: DateTime(2026, 1), balances: const {})];

      expect(scheduler.shouldRemind(entries, now), isFalse);
    });

    test('false when far from month-end and nothing logged yet', () {
      final now = DateTime(2026, 1, 5);

      expect(scheduler.shouldRemind(const [], now), isFalse);
    });

    test('true within the last 5 days of the month with nothing logged', () {
      // January 2026 has 31 days — the 27th is 4 days remaining.
      final now = DateTime(2026, 1, 27);

      expect(scheduler.shouldRemind(const [], now), isTrue);
    });

    test('true on the last day of the month with nothing logged', () {
      final now = DateTime(2026, 2, 28); // Feb 2026 is not a leap year.

      expect(scheduler.shouldRemind(const [], now), isTrue);
    });

    test('ignores other months\' entries when checking the current month', () {
      final now = DateTime(2026, 2, 27);
      final entries = [MonthlyEntry(month: DateTime(2026, 1), balances: const {})];

      expect(scheduler.shouldRemind(entries, now), isTrue);
    });
  });
}
