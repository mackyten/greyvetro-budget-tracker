import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'ghost_icon_button.dart';
import 'month_detail_screen.dart';
import 'month_row_tile.dart';
import 'solid_icon_button.dart';

/// Full month list, pushed from [HomeScreen]'s "Snapshots" nav card or its
/// "Recent snapshots" → See all link. Owns the add-month header button — the
/// design moved it here from Home, where it no longer appears.
class SnapshotsScreen extends StatefulWidget {
  const SnapshotsScreen({super.key, required this.repository});

  final BudgetRepository repository;

  @override
  State<SnapshotsScreen> createState() => _SnapshotsScreenState();
}

class _SnapshotsScreenState extends State<SnapshotsScreen> {
  static const int _pageSize = 20;
  static const double _loadMoreThreshold = 200;

  final ScrollController _scrollController = ScrollController();
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _loadMoreThreshold) {
      return;
    }
    setState(() => _visibleCount += _pageSize);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final repository = widget.repository;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  GhostIconButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Snapshots',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: uiFont,
                        color: palette.heading,
                      ),
                    ),
                  ),
                  StreamBuilder<List<MonthlyEntry>>(
                    stream: repository.watchMonthlyEntries(),
                    builder: (context, snap) {
                      return SolidIconButton(
                        icon: Icons.add,
                        onPressed: () => _addNextMonth(context, snap.data ?? const []),
                      );
                    },
                  ),
                ],
              ),
            ),
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

                      final visibleCount = _visibleCount < summaries.length
                          ? _visibleCount
                          : summaries.length;
                      final hasMore = visibleCount < summaries.length;

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                        itemCount: visibleCount + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= visibleCount) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                ),
                              ),
                            );
                          }

                          final summary = summaries[index];
                          final previous = entries
                              .where((e) => e.month.isBefore(summary.entry.month))
                              .fold<MonthlyEntry?>(
                                null,
                                (prev, e) => prev == null || e.month.isAfter(prev.month)
                                    ? e
                                    : prev,
                              );
                          return MonthRowTile(
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
    );
  }

  Future<void> _addNextMonth(
    BuildContext context,
    List<MonthlyEntry> entries,
  ) async {
    final repository = widget.repository;
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
