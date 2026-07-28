import 'account.dart';
import 'monthly_entry.dart';

/// Computed totals for a month, mirroring the spreadsheet's own formula rows
/// (Total Assets / Total Reserved & Liabilities / Savings / % change /
/// Current month saved). Never persisted — always derived from
/// [MonthlyEntry.balances] plus the account list so it can never drift from
/// the source data.
class MonthSummary {
  MonthSummary({
    required this.entry,
    required this.totalAssets,
    required this.totalReservedLiabilities,
    required this.netSavings,
    required this.currentMonthSaved,
    required this.momChangePct,
  });

  final MonthlyEntry entry;
  final double totalAssets;
  final double totalReservedLiabilities;
  final double netSavings;

  /// Null for the first tracked month (no prior month to diff against).
  final double? currentMonthSaved;
  final double? momChangePct;

  factory MonthSummary.compute({
    required MonthlyEntry entry,
    required MonthlyEntry? previous,
    required List<Account> accounts,
  }) {
    double sumSection(MonthlyEntry e, AccountSection section) {
      return accounts
          .where((a) => a.section == section)
          .fold(0.0, (sum, a) => sum + (e.balances[a.id] ?? 0));
    }

    final totalAssets = sumSection(entry, AccountSection.asset);
    final totalReservedLiabilities =
        sumSection(entry, AccountSection.reservedLiability);
    final netSavings = totalAssets - totalReservedLiabilities;

    double? currentMonthSaved;
    double? momChangePct;
    if (previous != null) {
      final prevAssets = sumSection(previous, AccountSection.asset);
      final prevReserved =
          sumSection(previous, AccountSection.reservedLiability);
      final prevNetSavings = prevAssets - prevReserved;
      currentMonthSaved = netSavings - prevNetSavings;
      momChangePct =
          prevNetSavings == 0 ? null : currentMonthSaved / prevNetSavings.abs();
    }

    return MonthSummary(
      entry: entry,
      totalAssets: totalAssets,
      totalReservedLiabilities: totalReservedLiabilities,
      netSavings: netSavings,
      currentMonthSaved: currentMonthSaved,
      momChangePct: momChangePct,
    );
  }
}
