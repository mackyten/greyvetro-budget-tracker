import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/account.dart';
import '../models/monthly_entry.dart';
import 'budget_repository.dart';

/// One-time import of the original "Net Worth / Liquidity Tracker" Numbers
/// sheet, bundled as `assets/seed/net_worth_seed.json`. Only runs when the
/// accounts collection is still empty, so it never overwrites live data.
Future<void> importSeedIfEmpty(BudgetRepository repo) async {
  final existing = await repo.watchAccounts().first;
  if (existing.isNotEmpty) return;

  final raw = await rootBundle.loadString('assets/seed/net_worth_seed.json');
  final seed = jsonDecode(raw) as Map<String, dynamic>;

  for (final a in (seed['accounts'] as List).cast<Map<String, dynamic>>()) {
    await repo.addAccount(Account.fromMap(a['id'] as String, a));
  }

  for (final e in (seed['monthlyEntries'] as List).cast<Map<String, dynamic>>()) {
    await repo.saveMonthlyEntry(MonthlyEntry.fromMap(e['id'] as String, e));
  }
}
