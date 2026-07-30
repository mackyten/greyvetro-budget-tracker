import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';

final _axisMonthFormat = DateFormat('MMM yy');

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.repository});

  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  fontFamily: uiFont,
                  color: palette.heading,
                ),
              ),
              Text(
                'Trends across all tracked months',
                style: TextStyle(fontSize: 12, fontFamily: uiFont, color: palette.muted),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: StreamBuilder<List<Account>>(
                  stream: repository.watchAccounts(),
                  builder: (context, accountsSnap) {
                    if (!accountsSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final accounts = accountsSnap.data!;
                    return StreamBuilder<List<MonthlyEntry>>(
                      stream: repository.watchMonthlyEntries(),
                      builder: (context, entriesSnap) {
                        if (!entriesSnap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final entries = entriesSnap.data!;

                        if (entries.isEmpty) {
                          return Center(
                            child: Text(
                              'No months tracked yet.',
                              style: TextStyle(fontFamily: uiFont, color: palette.muted),
                            ),
                          );
                        }

                        final summaries = computeMonthSummaries(
                          entries: entries,
                          accounts: accounts,
                        );

                        return ListView(
                          padding: const EdgeInsets.only(bottom: 96),
                          children: [
                            _ChartCard(
                              title: 'Net worth over time',
                              child: _NetWorthTrendChart(summaries: summaries),
                            ),
                            _ChartCard(
                              title: 'Assets vs. Reserved & Liabilities',
                              child: _AssetsVsLiabilitiesChart(summaries: summaries),
                            ),
                            _ChartCard(
                              title: 'Monthly saved amount',
                              child: _MonthlySavedChart(summaries: summaries),
                            ),
                            _ChartCard(
                              title: 'Latest balance breakdown',
                              child: _LatestBalanceBreakdownChart(
                                accounts: accounts,
                                latestEntry: summaries.last.entry,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: uiFont,
              color: palette.heading,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyChartMessage extends StatelessWidget {
  const _EmptyChartMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        message,
        style: TextStyle(fontSize: 12.5, fontFamily: uiFont, color: palette.muted),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

double _monthInterval(int count) => (count / 6).ceil().clamp(1, 999).toDouble();

Widget _bottomMonthLabel(List<MonthSummary> summaries, double value) {
  final index = value.round();
  if (index < 0 || index >= summaries.length) return const SizedBox.shrink();
  // fl_chart doesn't reliably honor SideTitles.interval on every chart type
  // (observed on BarChart), so gate here too — otherwise every index gets a
  // label and they overlap into an unreadable smear.
  final step = _monthInterval(summaries.length).round();
  if (index % step != 0) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(_axisMonthFormat.format(summaries[index].entry.month), style: const TextStyle(fontSize: 10)),
  );
}

Widget _leftAmountLabel(double value) {
  return Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Text(compactCurrencyFormat.format(value), style: const TextStyle(fontSize: 10)),
  );
}

FlTitlesData _axisTitles(List<MonthSummary> summaries) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: _monthInterval(summaries.length),
        getTitlesWidget: (value, meta) => _bottomMonthLabel(summaries, value),
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 56,
        getTitlesWidget: (value, meta) => _leftAmountLabel(value),
      ),
    ),
  );
}

/// Net worth (Assets − Reserved & Liabilities) per month. A single series, so
/// no legend — the card title already names what's plotted.
class _NetWorthTrendChart extends StatelessWidget {
  const _NetWorthTrendChart({required this.summaries});

  final List<MonthSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.length < 2) {
      return const _EmptyChartMessage('Track at least 2 months to see the net worth trend.');
    }
    const primary = AppPalette.blueDeep;
    final gridColor = Theme.of(context).colorScheme.outlineVariant;
    final spots = [
      for (var i = 0; i < summaries.length; i++) FlSpot(i.toDouble(), summaries[i].netSavings),
    ];

    return AspectRatio(
      aspectRatio: 1.6,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: primary,
              barWidth: 2,
              dotData: FlDotData(show: summaries.length <= 12),
              belowBarData: BarAreaData(show: true, color: primary.withValues(alpha: 0.1)),
            ),
          ],
          titlesData: _axisTitles(summaries),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => [
                for (final spot in touchedSpots)
                  LineTooltipItem(
                    '${monthFormat.format(summaries[spot.x.toInt()].entry.month)}\n'
                    '${currencyFormat.format(spot.y)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two named series on one shared amount axis (never a second, independent
/// y-scale) — a true identity comparison, so it gets the fixed validated
/// categorical pair plus a legend.
class _AssetsVsLiabilitiesChart extends StatelessWidget {
  const _AssetsVsLiabilitiesChart({required this.summaries});

  final List<MonthSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.length < 2) {
      return const _EmptyChartMessage('Track at least 2 months to compare assets and liabilities.');
    }
    const assetColor = AppPalette.colorblindBlue;
    const liabilityColor = AppPalette.colorblindOrange;
    final gridColor = Theme.of(context).colorScheme.outlineVariant;

    final assetSpots = [
      for (var i = 0; i < summaries.length; i++) FlSpot(i.toDouble(), summaries[i].totalAssets),
    ];
    final liabilitySpots = [
      for (var i = 0; i < summaries.length; i++)
        FlSpot(i.toDouble(), summaries[i].totalReservedLiabilities),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: assetColor, label: 'Assets'),
            const SizedBox(width: 16),
            _LegendDot(color: liabilityColor, label: 'Reserved & Liabilities'),
          ],
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1.6,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: assetSpots,
                  isCurved: true,
                  color: assetColor,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: liabilitySpots,
                  isCurved: true,
                  color: liabilityColor,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
              titlesData: _axisTitles(summaries),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }
}

/// Signed delta vs. a zero baseline. Bar direction (above/below zero) is the
/// primary, colorblind-safe encoding of sign; green/red reinforces it and
/// matches the convention already used for this exact figure in
/// MonthDetailScreen's summary bar and MonthListScreen's month tiles.
class _MonthlySavedChart extends StatelessWidget {
  const _MonthlySavedChart({required this.summaries});

  final List<MonthSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final points = [
      for (var i = 0; i < summaries.length; i++)
        if (summaries[i].currentMonthSaved != null) (i, summaries[i].currentMonthSaved!),
    ];
    if (points.isEmpty) {
      return const _EmptyChartMessage('Add another month to see monthly savings.');
    }
    final gridColor = Theme.of(context).colorScheme.outlineVariant;

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          barGroups: [
            for (final p in points)
              BarChartGroupData(
                x: p.$1,
                barRods: [
                  BarChartRodData(
                    toY: p.$2,
                    color: p.$2 >= 0 ? AppPalette.ok : AppPalette.error,
                    width: 14,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
          titlesData: _axisTitles(summaries),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

/// Comparing magnitude across many long-named accounts — a bar list, not a
/// donut (a pie past ~7 slices with close values is unreadable). One hue
/// (the app's brand color) since this is a magnitude job, not identity;
/// sorting by size does the "ordering" work a rainbow would otherwise fake.
class _LatestBalanceBreakdownChart extends StatelessWidget {
  const _LatestBalanceBreakdownChart({required this.accounts, required this.latestEntry});

  final List<Account> accounts;
  final MonthlyEntry latestEntry;

  @override
  Widget build(BuildContext context) {
    final rows = accounts
        .where((a) =>
            a.section == AccountSection.asset &&
            a.active &&
            (latestEntry.balances[a.id] ?? 0) > 0)
        .map((a) => (a.name, latestEntry.balances[a.id]!))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    if (rows.isEmpty) {
      return const _EmptyChartMessage('No balance data for the latest month.');
    }

    final maxValue = rows.first.$2;
    final primary = Theme.of(context).colorScheme.primary;
    final track = primary.withValues(alpha: 0.12);

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(row.$1, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(4)),
                      ),
                      FractionallySizedBox(
                        widthFactor: (row.$2 / maxValue).clamp(0.0, 1.0),
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: Text(
                    currencyFormat.format(row.$2),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
