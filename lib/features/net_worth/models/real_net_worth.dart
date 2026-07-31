import 'dart:math';

import 'month_summary.dart';

/// Expresses every month's nominal net worth in terms of today's purchasing
/// power (i.e. the most recent tracked month — locked-in baseline is
/// "today's pesos", not the first-tracked month's), given a constant annual
/// inflation rate compounded monthly. Older months are scaled *up* since a
/// peso then bought more than a peso now.
List<double> realNetWorthSeries({
  required List<MonthSummary> summaries,
  required double annualInflationRate,
}) {
  if (summaries.isEmpty) return const [];
  final monthlyRate = annualInflationRate / 12;
  final lastIndex = summaries.length - 1;
  return [
    for (var i = 0; i < summaries.length; i++)
      summaries[i].netSavings * pow(1 + monthlyRate, lastIndex - i),
  ];
}
