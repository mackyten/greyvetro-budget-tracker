import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../../../core/theme_controller.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'app_drawer.dart';
import 'gradient_fab.dart';
import 'ghost_icon_button.dart';
import 'month_detail_screen.dart';

class MonthListScreen extends StatelessWidget {
  const MonthListScreen({
    super.key,
    required this.repository,
    required this.themeController,
  });

  final BudgetRepository repository;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      drawer: AppDrawer(repository: repository, themeController: themeController),
      body: Builder(
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net Worth Tracker',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              fontFamily: uiFont,
                              color: palette.heading,
                            ),
                          ),
                          Text(
                            'Liquidity across all accounts',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: uiFont,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GhostIconButton(
                      icon: Icons.menu,
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ],
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
                                'No months tracked yet. Tap + to add one.',
                                style: TextStyle(fontFamily: uiFont, color: palette.muted),
                              ),
                            );
                          }

                          final summaries = computeMonthSummaries(
                            entries: entries,
                            accounts: accounts,
                          ).reversed.toList();

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: summaries.length,
                            itemBuilder: (context, index) {
                              final summary = summaries[index];
                              final previous = entries
                                  .where((e) => e.month.isBefore(summary.entry.month))
                                  .fold<MonthlyEntry?>(
                                    null,
                                    (prev, e) => prev == null || e.month.isAfter(prev.month)
                                        ? e
                                        : prev,
                                  );
                              return _MonthTile(
                                summary: summary,
                                onTap: () => showMonthDetailSheet(
                                  context,
                                  repository: repository,
                                  entry: summary.entry,
                                  accounts: accounts,
                                  previous: previous,
                                ),
                              );
                            },
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
      ),
      floatingActionButton: StreamBuilder<List<MonthlyEntry>>(
        stream: repository.watchMonthlyEntries(),
        builder: (context, snap) {
          return GradientFab(onPressed: () => _addNextMonth(context, snap.data ?? const []));
        },
      ),
    );
  }

  Future<void> _addNextMonth(
    BuildContext context,
    List<MonthlyEntry> entries,
  ) async {
    final DateTime nextMonth;
    if (entries.isEmpty) {
      final now = DateTime.now();
      nextMonth = DateTime(now.year, now.month);
    } else {
      final latest =
          entries.map((e) => e.month).reduce((a, b) => a.isAfter(b) ? a : b);
      nextMonth = DateTime(latest.year, latest.month + 1);
    }

    MonthlyEntry? existing;
    for (final e in entries) {
      if (e.month == nextMonth) existing = e;
    }
    final entry = existing ?? MonthlyEntry(month: nextMonth, balances: const {});

    final previous = entries
        .where((e) => e.month.isBefore(nextMonth))
        .fold<MonthlyEntry?>(
          null,
          (prev, e) => prev == null || e.month.isAfter(prev.month) ? e : prev,
        );

    final accounts = await repository.watchAccounts().first;

    if (!context.mounted) return;
    showMonthDetailSheet(
      context,
      repository: repository,
      entry: entry,
      accounts: accounts,
      previous: previous,
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({required this.summary, required this.onTap});

  final MonthSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final delta = summary.currentMonthSaved;
    final deltaColor = delta == null
        ? palette.muted
        : delta >= 0
            ? AppPalette.ok
            : AppPalette.error;

    final headerStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      fontFamily: uiFont,
      color: palette.heading,
    );
    final subtitleStyle = TextStyle(fontSize: 12, fontFamily: uiFont, color: palette.muted);
    final netStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      fontFamily: monoFont,
      color: palette.heading,
    );
    final deltaStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      fontFamily: monoFont,
      color: deltaColor,
    );

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(monthFormat.format(summary.entry.month), style: headerStyle),
        Text(
          'Assets ${currencyFormat.format(summary.totalAssets)} · '
          'Reserved ${currencyFormat.format(summary.totalReservedLiabilities)}',
          style: subtitleStyle,
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(currencyFormat.format(summary.netSavings), style: netStyle),
        if (delta != null) Text(formatSignedDelta(delta, summary.momChangePct), style: deltaStyle),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leftColumn),
                rightColumn,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
