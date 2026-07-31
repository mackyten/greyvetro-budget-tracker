import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:greyvetro_budget_tracker/features/net_worth/data/export_builder.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/data/import_reader.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/models/account.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/models/monthly_entry.dart';

final _accounts = [
  Account(id: 'cash', name: 'Cash Wallet', section: AccountSection.asset, order: 0),
  Account(
    id: 'card',
    name: 'Credit Card',
    section: AccountSection.reservedLiability,
    reservedKind: ReservedKind.creditCard,
    order: 1,
  ),
];

final _entries = [
  MonthlyEntry(
    month: DateTime(2026, 1),
    balances: {'cash': 12345.6, 'card': 500},
    note: 'First month',
  ),
  MonthlyEntry(
    month: DateTime(2026, 2),
    balances: {'cash': 15000, 'card': 200},
    locked: true,
  ),
];

void main() {
  group('buildCsv', () {
    test('includes a header row and one row per month with grouped amounts', () {
      final csv = buildCsv(_accounts, _entries);
      final lines = csv.trim().split('\r\n');

      expect(lines, hasLength(3));
      expect(lines[0], contains('Cash Wallet'));
      expect(lines[0], contains('Credit Card'));
      expect(lines[1], contains('12,345.60'));
      expect(lines[2], contains('Yes')); // locked column for the Feb entry
    });
  });

  group('buildPdf', () {
    test('produces non-empty PDF bytes without throwing', () async {
      final bytes = await buildPdf(_accounts, _entries);
      expect(bytes, isNotEmpty);
      // PDF files start with the "%PDF-" magic bytes.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('buildBackupJson / parseBackup round trip', () {
    test('round-trips accounts and monthly entries losslessly', () {
      final backup = buildBackupJson(_accounts, _entries);
      final raw = jsonEncode(backup);

      final outcome = parseBackup(raw);

      expect(outcome, isA<ImportParsed>());
      final parsed = outcome as ImportParsed;
      expect(parsed.accounts, hasLength(2));
      expect(parsed.entries, hasLength(2));
      expect(parsed.accounts.firstWhere((a) => a.id == 'cash').name, 'Cash Wallet');
      final feb = parsed.entries.firstWhere((e) => e.id == '2026-02');
      expect(feb.locked, isTrue);
      expect(feb.balances['cash'], 15000);
    });
  });

  group('parseBackup validation', () {
    test('rejects invalid JSON', () {
      final outcome = parseBackup('not json');
      expect(outcome, isA<ImportRejected>());
    });

    test('rejects a JSON value that is not an object', () {
      final outcome = parseBackup(jsonEncode([1, 2, 3]));
      expect(outcome, isA<ImportRejected>());
    });

    test('rejects a missing/mismatched format version', () {
      final outcome = parseBackup(jsonEncode({'accounts': [], 'monthlyEntries': []}));
      expect(outcome, isA<ImportRejected>());
      expect((outcome as ImportRejected).reason, contains('version'));
    });

    test('rejects a backup missing its accounts list', () {
      final outcome = parseBackup(jsonEncode({'formatVersion': 1, 'monthlyEntries': []}));
      expect(outcome, isA<ImportRejected>());
    });

    test('rejects malformed records without throwing', () {
      final outcome = parseBackup(jsonEncode({
        'formatVersion': 1,
        'accounts': [
          {'id': 'a'}, // missing required 'name'/'section' fields
        ],
        'monthlyEntries': [],
      }));
      expect(outcome, isA<ImportRejected>());
    });
  });
}
