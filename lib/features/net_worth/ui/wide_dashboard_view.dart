import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'auto_fit_grid.dart';
import 'net_worth_trends_section.dart';

/// Wide-layout Dashboard: the same net-worth data and six charts the mobile
/// Home screen's Trends section shows, reflowed into the verified design's
/// KPI-row + multi-column grid layout instead of one scrolling column.
class WideDashboardView extends StatelessWidget {
  const WideDashboardView({
    super.key,
    required this.accounts,
    required this.entries,
    required this.onSeeAllSnapshots,
    required this.onSelectEntry,
  });

  final List<Account> accounts;
  final List<MonthlyEntry> entries;
  final VoidCallback onSeeAllSnapshots;
  final ValueChanged<String> onSelectEntry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final summaries = computeMonthSummaries(entries: entries, accounts: accounts);
    final recent = summaries.reversed.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            fontFamily: uiFont,
            color: palette.heading,
          ),
        ),
        const SizedBox(height: 20),
        _KpiRow(summaries: summaries),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final chartCard = ChartCard(
              title: 'Net worth over time',
              child: NetWorthTrendChart(summaries: summaries),
            );
            final snapshotsCard = _RecentSnapshotsCard(
              recent: recent,
              onSeeAll: onSeeAllSnapshots,
              onSelectEntry: onSelectEntry,
            );
            if (constraints.maxWidth >= 640) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: chartCard),
                    const SizedBox(width: 20),
                    Expanded(child: snapshotsCard),
                  ],
                ),
              );
            }
            return Column(
              children: [chartCard, const SizedBox(height: 20), snapshotsCard],
            );
          },
        ),
        const SizedBox(height: 4),
        AutoFitGrid(
          minItemWidth: 300,
          children: [
            ChartCard(
              title: 'Assets vs. Reserved & Liabilities',
              child: AssetsVsLiabilitiesChart(summaries: summaries),
            ),
            ChartCard(
              title: 'Monthly saved amount',
              child: MonthlySavedChart(summaries: summaries),
            ),
            ChartCard(
              title: 'Latest balance breakdown',
              child: LatestBalanceBreakdownChart(accounts: accounts, summaries: summaries),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AutoFitGrid(
          minItemWidth: 320,
          children: [
            ChartCard(
              title: 'Assets breakdown',
              child: BalanceBreakdownPie(
                accounts: accounts,
                summaries: summaries,
                section: AccountSection.asset,
                emptyMessage: 'No active asset balances yet.',
              ),
            ),
            ChartCard(
              title: 'Reserved & Liabilities breakdown',
              child: BalanceBreakdownPie(
                accounts: accounts,
                summaries: summaries,
                section: AccountSection.reservedLiability,
                emptyMessage: 'No active reserved or liability balances yet.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.summaries});

  final List<MonthSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final latest = summaries.isEmpty ? null : summaries.last;
    final prev = summaries.length >= 2 ? summaries[summaries.length - 2] : null;

    String? netDelta;
    String? assetsDelta;
    String? reservedDelta;
    var netDeltaPos = true;
    if (latest != null && prev != null) {
      final dNet = latest.netSavings - prev.netSavings;
      netDeltaPos = dNet >= 0;
      netDelta = formatSignedDelta(dNet, latest.momChangePct);
      final dAssets = latest.totalAssets - prev.totalAssets;
      assetsDelta = '${dAssets >= 0 ? '+' : ''}${currencyFormat.format(dAssets)} vs last month';
      final dReserved = latest.totalReservedLiabilities - prev.totalReservedLiabilities;
      reservedDelta =
          '${dReserved >= 0 ? '+' : ''}${currencyFormat.format(dReserved)} vs last month';
    }

    return AutoFitGrid(
      minItemWidth: 220,
      children: [
        _KpiCard(
          label: 'Net worth',
          value: currencyFormat.format(latest?.netSavings ?? 0),
          accentColor: AppPalette.blueDeep,
          pillText: netDelta,
          pillColor: netDeltaPos ? AppPalette.ok : AppPalette.error,
        ),
        _KpiCard(
          label: 'Total assets',
          value: currencyFormat.format(latest?.totalAssets ?? 0),
          accentColor: AppPalette.colorblindBlue,
          pillText: assetsDelta,
          neutralPill: true,
        ),
        _KpiCard(
          label: 'Reserved & liabilities',
          value: currencyFormat.format(latest?.totalReservedLiabilities ?? 0),
          accentColor: AppPalette.pinkDeep,
          pillText: reservedDelta,
          neutralPill: true,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.accentColor,
    this.pillText,
    this.pillColor,
    this.neutralPill = false,
  });

  final String label;
  final String value;
  final Color accentColor;
  final String? pillText;
  final Color? pillColor;
  final bool neutralPill;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: accentColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 17, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontFamily: uiFont,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    fontFamily: monoFont,
                    color: palette.heading,
                  ),
                ),
                if (pillText != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: neutralPill ? palette.surfaceAlt : pillColor!.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pillText!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: neutralPill ? FontWeight.w700 : FontWeight.w800,
                        fontFamily: neutralPill ? uiFont : monoFont,
                        color: neutralPill ? palette.text : pillColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSnapshotsCard extends StatelessWidget {
  const _RecentSnapshotsCard({
    required this.recent,
    required this.onSeeAll,
    required this.onSelectEntry,
  });

  final List<MonthSummary> recent;
  final VoidCallback onSeeAll;
  final ValueChanged<String> onSelectEntry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT SNAPSHOTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontFamily: uiFont,
                  color: AppPalette.blueDeep,
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.blueDeep,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('See all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No months tracked yet.',
                style: TextStyle(fontFamily: uiFont, color: palette.muted),
              ),
            )
          else
            for (final summary in recent)
              _MiniSnapshotRow(
                summary: summary,
                onTap: () => onSelectEntry(summary.entry.id),
              ),
        ],
      ),
    );
  }
}

class _MiniSnapshotRow extends StatelessWidget {
  const _MiniSnapshotRow({required this.summary, required this.onTap});

  final MonthSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.border))),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.blueDeep.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                monthAbbrevFormat.format(summary.entry.month).toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: uiFont,
                  color: AppPalette.blueDeep,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monthFormat.format(summary.entry.month),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: uiFont,
                      color: palette.heading,
                    ),
                  ),
                  Text(
                    'Assets ${currencyFormat.format(summary.totalAssets)} · '
                    'Reserved ${currencyFormat.format(summary.totalReservedLiabilities)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontFamily: uiFont, color: palette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              currencyFormat.format(summary.netSavings),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: monoFont,
                color: palette.heading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
