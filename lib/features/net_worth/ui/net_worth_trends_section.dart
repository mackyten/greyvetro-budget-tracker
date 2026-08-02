import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../data/net_worth_preferences.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import '../models/net_worth_projection.dart';
import '../models/real_net_worth.dart';

final _axisMonthFormat = DateFormat('MMM yy');

/// Renders the Home screen's "Trends" section: every chart/metric card
/// derived from the tracked months, in the design's order — net worth
/// trend, the what-if projection banner (an existing feature the current
/// design mockup doesn't show but that isn't being dropped), assets vs.
/// reserved & liabilities, monthly saved amount, latest balance breakdown,
/// and the two balance-breakdown donuts. Each card handles its own
/// "not enough data yet" empty state rather than the section as a whole,
/// matching the design's per-card `emptyStyle` behavior — there's no single
/// blanket "no months tracked" message replacing the whole section.
class NetWorthTrendsSection extends StatelessWidget {
  const NetWorthTrendsSection({super.key, required this.accounts, required this.entries});

  final List<Account> accounts;
  final List<MonthlyEntry> entries;

  @override
  Widget build(BuildContext context) {
    final summaries = computeMonthSummaries(entries: entries, accounts: accounts);
    return Column(
      children: [
        _ChartCard(
          title: 'Net worth over time',
          child: _NetWorthTrendChart(summaries: summaries),
        ),
        _ProjectionBanner(summaries: summaries),
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
          child: _LatestBalanceBreakdownChart(accounts: accounts, summaries: summaries),
        ),
        _ChartCard(
          title: 'Assets breakdown',
          child: _BalanceBreakdownPie(
            accounts: accounts,
            summaries: summaries,
            section: AccountSection.asset,
            emptyMessage: 'No active asset balances yet.',
          ),
        ),
        _ChartCard(
          title: 'Reserved & Liabilities breakdown',
          child: _BalanceBreakdownPie(
            accounts: accounts,
            summaries: summaries,
            section: AccountSection.reservedLiability,
            emptyMessage: 'No active reserved or liability balances yet.',
          ),
        ),
      ],
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
      width: double.infinity,
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

/// Net worth (Assets − Reserved & Liabilities) per month. Single series (no
/// legend, card title names what's plotted) unless an inflation rate is set
/// in Settings, in which case a second, inflation-adjusted line is layered
/// on using the same two-series + [_LegendDot] pattern as
/// [_AssetsVsLiabilitiesChart].
class _NetWorthTrendChart extends StatefulWidget {
  const _NetWorthTrendChart({required this.summaries});

  final List<MonthSummary> summaries;

  @override
  State<_NetWorthTrendChart> createState() => _NetWorthTrendChartState();
}

class _NetWorthTrendChartState extends State<_NetWorthTrendChart> {
  double _inflationRate = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadInflationRate();
  }

  Future<void> _loadInflationRate() async {
    final rate = await NetWorthPreferences.instance.getAnnualInflationRate();
    if (!mounted) return;
    setState(() {
      _inflationRate = rate;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaries = widget.summaries;
    if (summaries.length < 2) {
      return const _EmptyChartMessage('Track at least 2 months to see the net worth trend.');
    }
    const primary = AppPalette.blueDeep;
    const realColor = AppPalette.colorblindOrange;
    final gridColor = Theme.of(context).colorScheme.outlineVariant;

    final spots = [
      for (var i = 0; i < summaries.length; i++) FlSpot(i.toDouble(), summaries[i].netSavings),
    ];

    final showReal = _loaded && _inflationRate > 0;
    final realSeries = showReal
        ? realNetWorthSeries(summaries: summaries, annualInflationRate: _inflationRate)
        : const <double>[];
    final realSpots = [
      for (var i = 0; i < realSeries.length; i++) FlSpot(i.toDouble(), realSeries[i]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showReal) ...[
          Row(
            children: [
              _LegendDot(color: primary, label: 'Net worth'),
              const SizedBox(width: 16),
              _LegendDot(color: realColor, label: "Inflation-adjusted (today's pesos)"),
            ],
          ),
          const SizedBox(height: 12),
        ],
        AspectRatio(
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
                  belowBarData: BarAreaData(show: !showReal, color: primary.withValues(alpha: 0.1)),
                ),
                if (showReal)
                  LineChartBarData(
                    spots: realSpots,
                    isCurved: true,
                    color: realColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    dashArray: const [6, 4],
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
        ),
      ],
    );
  }
}

/// What-if projector (#8): a text banner reusing [_ChartCard]'s chrome, not
/// its chart internals. Reuses the same target-amount preference as
/// milestones (#10a) rather than a second, bespoke "target" concept — the
/// nearest not-yet-reached target becomes the projection's target.
class _ProjectionBanner extends StatefulWidget {
  const _ProjectionBanner({required this.summaries});

  final List<MonthSummary> summaries;

  @override
  State<_ProjectionBanner> createState() => _ProjectionBannerState();
}

class _ProjectionBannerState extends State<_ProjectionBanner> {
  double? _nextTarget;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadNextTarget();
  }

  Future<void> _loadNextTarget() async {
    final targets = await NetWorthPreferences.instance.getTargets();
    final currentNetWorth = widget.summaries.isEmpty ? 0.0 : widget.summaries.last.netSavings;
    final upcoming = targets.where((t) => t > currentNetWorth).toList()..sort();
    if (!mounted) return;
    setState(() {
      _nextTarget = upcoming.isEmpty ? null : upcoming.first;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (!_loaded) return const SizedBox.shrink();

    final projection = computeProjection(summaries: widget.summaries, targetAmount: _nextTarget);
    final textStyle = TextStyle(fontSize: 12.5, fontFamily: uiFont, color: palette.text);

    if (projection == null) {
      return _ChartCard(
        title: 'Projection',
        child: Text(
          "You're not currently saving on average, based on recent months — no projection to show.",
          style: textStyle,
        ),
      );
    }

    final monthsToTarget = projection.monthsToTarget;
    final target = _nextTarget;
    final text = (monthsToTarget == null || target == null)
        ? 'At an average of ${currencyFormat.format(projection.averageMonthlySavings)} saved '
            'per month recently, your net worth keeps growing.'
        : 'At an average of ${currencyFormat.format(projection.averageMonthlySavings)} saved '
            "per month, you'll reach ${currencyFormat.format(target)} in about "
            '$monthsToTarget month${monthsToTarget == 1 ? '' : 's'}.';

    return _ChartCard(title: 'Projection', child: Text(text, style: textStyle));
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
/// MonthDetailScreen's summary bar and MonthRowTile's month tiles.
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
  const _LatestBalanceBreakdownChart({required this.accounts, required this.summaries});

  final List<Account> accounts;
  final List<MonthSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const _EmptyChartMessage('No balance data for the latest month.');
    }
    final latestEntry = summaries.last.entry;
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

/// Donut + legend for the latest month's active, positive-balance accounts
/// within one [section] — same filter/sort as [_LatestBalanceBreakdownChart],
/// rendered as identity/proportion (a handful of slices) rather than
/// magnitude-across-many-rows. Colors cycle through the same 6-color
/// sequence the design's `PIE_COLORS` array uses.
class _BalanceBreakdownPie extends StatelessWidget {
  const _BalanceBreakdownPie({
    required this.accounts,
    required this.summaries,
    required this.section,
    required this.emptyMessage,
  });

  final List<Account> accounts;
  final List<MonthSummary> summaries;
  final AccountSection section;
  final String emptyMessage;

  static const _colors = [
    AppPalette.blueDeep,
    AppPalette.pinkDeep,
    AppPalette.ok,
    AppPalette.colorblindOrange,
    AppPalette.pieGold,
    AppPalette.colorblindBlue,
  ];

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return _EmptyChartMessage(emptyMessage);
    }
    final latestEntry = summaries.last.entry;
    final rows = accounts
        .where((a) => a.section == section && a.active && (latestEntry.balances[a.id] ?? 0) > 0)
        .map((a) => (a.name, latestEntry.balances[a.id]!))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    if (rows.isEmpty) {
      return _EmptyChartMessage(emptyMessage);
    }

    final total = rows.fold<double>(0, (sum, r) => sum + r.$2);
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (var i = 0; i < rows.length; i++)
                  PieChartSectionData(
                    value: rows[i].$2,
                    color: _colors[i % _colors.length],
                    radius: 18,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _colors[i % _colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rows[i].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontFamily: uiFont, color: palette.text),
                        ),
                      ),
                      Text(
                        '${((rows[i].$2 / total) * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: monoFont,
                          color: palette.heading,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
