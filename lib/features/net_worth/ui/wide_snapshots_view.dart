import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'month_detail_screen.dart';
import 'month_row_tile.dart';

/// Wide-layout Snapshots: a scrollable month list and an inline editing
/// panel side by side (each independently scrollable, divided by a vertical
/// rule), replacing the mobile full-screen list + modal-sheet-per-month flow
/// — matches the verified design's already-iterated-on desktop Snapshots
/// module ("give each column its own capped height and independent
/// scroll").
class WideSnapshotsView extends StatelessWidget {
  const WideSnapshotsView({
    super.key,
    required this.repository,
    required this.accounts,
    required this.entries,
    required this.selectedEntryId,
    required this.onSelectEntry,
  });

  final BudgetRepository repository;
  final List<Account> accounts;
  final List<MonthlyEntry> entries;
  final String? selectedEntryId;
  final ValueChanged<String?> onSelectEntry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final summaries = computeMonthSummaries(entries: entries, accounts: accounts).reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Snapshots',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                fontFamily: uiFont,
                color: palette.heading,
              ),
            ),
            Material(
              color: AppPalette.blueDeep,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelectEntry(_nextMonthId(entries)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Text(
                    '+ Add month',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: uiFont,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 300,
                child: summaries.isEmpty
                    ? Center(
                        child: Text(
                          'No months tracked yet.',
                          style: TextStyle(fontFamily: uiFont, color: palette.muted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: summaries.length,
                        itemBuilder: (context, index) {
                          final summary = summaries[index];
                          return MonthRowTile(
                            summary: summary,
                            selected: summary.entry.id == selectedEntryId,
                            onTap: () => onSelectEntry(summary.entry.id),
                          );
                        },
                      ),
              ),
              Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 24), color: palette.border),
              Expanded(
                child: selectedEntryId == null
                    ? const _EmptyDetail()
                    : _DetailPanel(
                        key: ValueKey(selectedEntryId),
                        repository: repository,
                        accounts: accounts,
                        entries: entries,
                        entryId: selectedEntryId!,
                        onClose: () => onSelectEntry(null),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    super.key,
    required this.repository,
    required this.accounts,
    required this.entries,
    required this.entryId,
    required this.onClose,
  });

  final BudgetRepository repository;
  final List<Account> accounts;
  final List<MonthlyEntry> entries;
  final String entryId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entry = _resolveEntry(entryId, entries);
    final previous = _previousEntryFor(entry, entries);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: MonthDetailSheet(
        repository: repository,
        entry: entry,
        accounts: accounts,
        previous: previous,
        embedded: true,
        onClose: onClose,
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_outlined, size: 32, color: palette.muted),
            const SizedBox(height: 10),
            Text(
              'Select a snapshot to edit, or add a new month.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: uiFont, color: palette.muted, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same "next month after the latest tracked one" rule as the mobile
/// Snapshots screen's add-month button.
String _nextMonthId(List<MonthlyEntry> entries) {
  final DateTime nextMonth;
  if (entries.isEmpty) {
    final now = DateTime.now();
    nextMonth = DateTime(now.year, now.month);
  } else {
    final latest = entries.map((e) => e.month).reduce((a, b) => a.isAfter(b) ? a : b);
    nextMonth = DateTime(latest.year, latest.month + 1);
  }
  return '${nextMonth.year.toString().padLeft(4, '0')}-${nextMonth.month.toString().padLeft(2, '0')}';
}

/// Looks up [id] in [entries]; if it isn't there yet (a month just picked
/// via "+ Add month", not yet saved), reconstructs a blank entry from the
/// id alone — [MonthlyEntry.id] is a deterministic function of its month, so
/// no separate transient-entry state is needed anywhere.
MonthlyEntry _resolveEntry(String id, List<MonthlyEntry> entries) {
  for (final e in entries) {
    if (e.id == id) return e;
  }
  final parts = id.split('-');
  return MonthlyEntry(month: DateTime(int.parse(parts[0]), int.parse(parts[1])), balances: const {});
}

MonthlyEntry? _previousEntryFor(MonthlyEntry entry, List<MonthlyEntry> entries) {
  return entries.where((e) => e.month.isBefore(entry.month)).fold<MonthlyEntry?>(
        null,
        (prev, e) => prev == null || e.month.isAfter(prev.month) ? e : prev,
      );
}
