import 'month_summary.dart';

/// A simple what-if projection based on the trailing average of
/// month-over-month savings — deliberately not a fitted trendline, since the
/// point is a rough "at this pace" nudge, not false precision.
class NetWorthProjection {
  const NetWorthProjection({
    required this.averageMonthlySavings,
    required this.currentNetWorth,
    this.targetAmount,
    this.monthsToTarget,
  });

  final double averageMonthlySavings;
  final double currentNetWorth;

  /// Same target-amount concept as milestones (#10a) — not a second, bespoke
  /// "target" idea.
  final double? targetAmount;

  /// Null when there's no target, or the target is already met.
  final int? monthsToTarget;
}

/// Returns `null` — a distinct "not currently saving" case, rather than a
/// nonsensical projection — when the trailing average is at or below zero.
NetWorthProjection? computeProjection({
  required List<MonthSummary> summaries,
  int lookbackMonths = 6,
  double? targetAmount,
}) {
  final deltas = [
    for (final s in summaries.reversed.take(lookbackMonths))
      if (s.currentMonthSaved != null) s.currentMonthSaved!,
  ];
  if (deltas.isEmpty) return null;

  final average = deltas.reduce((a, b) => a + b) / deltas.length;
  if (average <= 0) return null;

  final currentNetWorth = summaries.last.netSavings;
  int? monthsToTarget;
  if (targetAmount != null && targetAmount > currentNetWorth) {
    monthsToTarget = ((targetAmount - currentNetWorth) / average).ceil();
  }

  return NetWorthProjection(
    averageMonthlySavings: average,
    currentNetWorth: currentNetWorth,
    targetAmount: targetAmount,
    monthsToTarget: monthsToTarget,
  );
}
