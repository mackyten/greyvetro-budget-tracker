import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/format.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';

/// The only file in the net-worth feature that touches `csv`/`pdf`. Builds
/// three interchangeable representations of the same data:
///  - [buildCsv]/[buildPdf]: read-only exports for the user's own records.
///  - [buildBackupJson]: a full, round-trippable snapshot consumed by
///    `import_reader.dart` — the only one of the three actually re-imported.
///
/// Deliberately never touches anything from `lib/features/vault/` — vault
/// data stays permanently excluded from export/import.
final _amountFormat = NumberFormat('#,##0.00');

List<List<String>> _rows(List<Account> accounts, List<MonthlyEntry> entries) {
  final sortedAccounts = List<Account>.from(accounts)
    ..sort((a, b) => a.order.compareTo(b.order));
  final summaries = computeMonthSummaries(entries: entries, accounts: accounts);

  final header = [
    'Month',
    for (final a in sortedAccounts) a.name,
    'Total Assets',
    'Total Reserved & Liabilities',
    'Net Savings',
    'Locked',
    'Note',
  ];

  final rows = [
    header,
    for (final summary in summaries)
      [
        monthFormat.format(summary.entry.month),
        for (final a in sortedAccounts)
          summary.entry.balances[a.id] != null
              ? _amountFormat.format(summary.entry.balances[a.id])
              : '',
        _amountFormat.format(summary.totalAssets),
        _amountFormat.format(summary.totalReservedLiabilities),
        _amountFormat.format(summary.netSavings),
        summary.entry.locked ? 'Yes' : 'No',
        summary.entry.note ?? '',
      ],
  ];
  return rows;
}

String buildCsv(List<Account> accounts, List<MonthlyEntry> entries) {
  return const CsvEncoder().convert(_rows(accounts, entries));
}

Future<Uint8List> buildPdf(List<Account> accounts, List<MonthlyEntry> entries) async {
  final rows = _rows(accounts, entries);
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Header(text: 'Net Worth Tracker Export'),
        pw.TableHelper.fromTextArray(
          headers: rows.first,
          data: rows.skip(1).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ),
  );
  return doc.save();
}

Map<String, dynamic> buildBackupJson(List<Account> accounts, List<MonthlyEntry> entries) {
  return {
    'formatVersion': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'accounts': [for (final a in accounts) {'id': a.id, ...a.toMap()}],
    'monthlyEntries': [for (final e in entries) {'id': e.id, ...e.toMap()}],
  };
}
