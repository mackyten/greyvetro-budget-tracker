import 'package:flutter_test/flutter_test.dart';

import 'package:vetro_ledger/features/net_worth/models/account.dart';
import 'package:vetro_ledger/features/net_worth/models/month_summary.dart';
import 'package:vetro_ledger/features/net_worth/models/monthly_entry.dart';
import 'package:vetro_ledger/features/net_worth/models/net_worth_projection.dart';
import 'package:vetro_ledger/features/net_worth/models/real_net_worth.dart';
import 'package:vetro_ledger/features/net_worth/models/streak.dart';

final _accounts = [
  Account(id: 'cash', name: 'Cash', section: AccountSection.asset, order: 0),
];

List<MonthSummary> _summariesForBalances(List<double> balances, {DateTime? start}) {
  final startMonth = start ?? DateTime(2026, 1);
  final entries = [
    for (var i = 0; i < balances.length; i++)
      MonthlyEntry(
        month: DateTime(startMonth.year, startMonth.month + i),
        balances: {'cash': balances[i]},
      ),
  ];
  return computeMonthSummaries(entries: entries, accounts: _accounts);
}

void main() {
  group('realNetWorthSeries', () {
    test('empty input yields empty output', () {
      expect(realNetWorthSeries(summaries: const [], annualInflationRate: 0.04), isEmpty);
    });

    test('zero inflation rate leaves values unchanged', () {
      final summaries = _summariesForBalances([100000, 110000, 120000]);
      final series = realNetWorthSeries(summaries: summaries, annualInflationRate: 0);
      expect(series, [100000, 110000, 120000]);
    });

    test('discounts to today\'s pesos — the most recent month is unscaled, older months scale up', () {
      final summaries = _summariesForBalances([100000, 100000, 100000]);
      final series = realNetWorthSeries(summaries: summaries, annualInflationRate: 0.12);

      // Most recent (today) month is unscaled.
      expect(series.last, closeTo(100000, 0.01));
      // Older months are scaled up (a peso then bought more than now).
      expect(series[0], greaterThan(series[1]));
      expect(series[1], greaterThan(series[2]));
    });
  });

  group('computeProjection', () {
    test('null when there is no month-over-month data at all', () {
      final summaries = _summariesForBalances([100000]);
      expect(computeProjection(summaries: summaries), isNull);
    });

    test('null ("not currently saving") when the trailing average is negative', () {
      final summaries = _summariesForBalances([100000, 90000, 80000]);
      expect(computeProjection(summaries: summaries), isNull);
    });

    test('computes months-to-target when saving on average', () {
      final summaries = _summariesForBalances([100000, 110000, 120000]);
      final projection = computeProjection(summaries: summaries, targetAmount: 140000);

      expect(projection, isNotNull);
      expect(projection!.averageMonthlySavings, closeTo(10000, 0.01));
      expect(projection.monthsToTarget, 2);
    });

    test('null monthsToTarget when the target is already met', () {
      final summaries = _summariesForBalances([100000, 110000, 120000]);
      final projection = computeProjection(summaries: summaries, targetAmount: 50000);

      expect(projection, isNotNull);
      expect(projection!.monthsToTarget, isNull);
    });
  });

  group('computeLoggedStreak', () {
    test('zero with no entries', () {
      expect(computeLoggedStreak(const []), 0);
    });

    test('counts consecutive months ending at the current month', () {
      final entries = [
        MonthlyEntry(month: DateTime(2025, 11), balances: const {}),
        MonthlyEntry(month: DateTime(2025, 12), balances: const {}),
        MonthlyEntry(month: DateTime(2026, 1), balances: const {}),
      ];
      expect(computeLoggedStreak(entries, asOf: DateTime(2026, 1, 15)), 3);
    });

    test('does not penalize an in-progress current month that has no entry yet', () {
      final entries = [
        MonthlyEntry(month: DateTime(2025, 12), balances: const {}),
        MonthlyEntry(month: DateTime(2026, 1), balances: const {}),
      ];
      // asOf is February, but February hasn't been logged yet.
      expect(computeLoggedStreak(entries, asOf: DateTime(2026, 2, 3)), 2);
    });

    test('breaks on a gap', () {
      final entries = [
        MonthlyEntry(month: DateTime(2025, 10), balances: const {}),
        // November missing.
        MonthlyEntry(month: DateTime(2025, 12), balances: const {}),
        MonthlyEntry(month: DateTime(2026, 1), balances: const {}),
      ];
      expect(computeLoggedStreak(entries, asOf: DateTime(2026, 1, 20)), 2);
    });
  });
}
