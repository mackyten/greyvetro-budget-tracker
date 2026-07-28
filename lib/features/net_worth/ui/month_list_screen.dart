import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'dashboard_screen.dart';
import 'manage_accounts_screen.dart';
import 'month_detail_screen.dart';

class MonthListScreen extends StatelessWidget {
  const MonthListScreen({super.key, required this.repository});

  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Net Worth / Liquidity Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Dashboard',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DashboardScreen(repository: repository),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Manage accounts',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ManageAccountsScreen(repository: repository),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Account>>(
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
              final entries = List<MonthlyEntry>.from(entriesSnap.data!)
                ..sort((a, b) => a.month.compareTo(b.month));

              if (entries.isEmpty) {
                return const Center(
                  child: Text('No months tracked yet. Tap + to add one.'),
                );
              }

              final summaries = <MonthSummary>[
                for (var i = 0; i < entries.length; i++)
                  MonthSummary.compute(
                    entry: entries[i],
                    previous: i > 0 ? entries[i - 1] : null,
                    accounts: accounts,
                  ),
              ].reversed.toList();

              return ListView.separated(
                itemCount: summaries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MonthDetailScreen(
                          repository: repository,
                          entry: summary.entry,
                          accounts: accounts,
                          previous: previous,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<List<MonthlyEntry>>(
        stream: repository.watchMonthlyEntries(),
        builder: (context, snap) {
          return FloatingActionButton(
            onPressed: () => _addNextMonth(context, snap.data ?? const []),
            tooltip: 'Add month',
            child: const Icon(Icons.add),
          );
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MonthDetailScreen(
          repository: repository,
          entry: entry,
          accounts: accounts,
          previous: previous,
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({required this.summary, required this.onTap});

  final MonthSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final delta = summary.currentMonthSaved;
    final deltaColor = delta == null
        ? null
        : delta >= 0
            ? Colors.green.shade700
            : Colors.red.shade700;

    return ListTile(
      onTap: onTap,
      title: Text(monthFormat.format(summary.entry.month)),
      subtitle: Text(
        'Assets ${currencyFormat.format(summary.totalAssets)}  ·  '
        'Reserved & Liabilities ${currencyFormat.format(summary.totalReservedLiabilities)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currencyFormat.format(summary.netSavings),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (delta != null)
            Text(
              '${delta >= 0 ? '+' : ''}${currencyFormat.format(delta)}',
              style: TextStyle(color: deltaColor, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
