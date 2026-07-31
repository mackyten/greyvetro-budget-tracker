import 'dart:convert';

import '../models/account.dart';
import '../models/monthly_entry.dart';

const _supportedFormatVersion = 1;

/// Result of parsing a previously-exported JSON backup — either fully
/// parsed, or rejected with a reason. There is no partial/intermediate
/// state: a bad file never yields a half-populated [ImportParsed].
sealed class ImportOutcome {}

class ImportParsed extends ImportOutcome {
  ImportParsed({required this.accounts, required this.entries});

  final List<Account> accounts;
  final List<MonthlyEntry> entries;
}

class ImportRejected extends ImportOutcome {
  ImportRejected(this.reason);

  final String reason;
}

/// Parses and validates a backup produced by `export_builder.dart`'s
/// `buildBackupJson`. Never touches a repository — the caller decides
/// whether/how to apply the result after the user confirms a diff summary.
ImportOutcome parseBackup(String raw) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return ImportRejected('This file is not valid JSON.');
  }

  if (decoded is! Map<String, dynamic>) {
    return ImportRejected('This file is not a recognized backup — expected a JSON object.');
  }

  final version = decoded['formatVersion'];
  if (version != _supportedFormatVersion) {
    return ImportRejected(
      version == null
          ? 'This file is missing a backup version and cannot be imported.'
          : 'Unsupported backup version ($version) — this app supports version $_supportedFormatVersion.',
    );
  }

  final rawAccounts = decoded['accounts'];
  final rawEntries = decoded['monthlyEntries'];
  if (rawAccounts is! List) {
    return ImportRejected('This backup is missing its accounts list.');
  }
  if (rawEntries is! List) {
    return ImportRejected('This backup is missing its monthly entries list.');
  }

  try {
    final accounts = [
      for (final raw in rawAccounts) _parseAccount(raw),
    ];
    final entries = [
      for (final raw in rawEntries) _parseEntry(raw),
    ];
    return ImportParsed(accounts: accounts, entries: entries);
  } catch (e) {
    return ImportRejected('This backup contains malformed records and cannot be imported: $e');
  }
}

Account _parseAccount(dynamic raw) {
  final map = raw as Map<String, dynamic>;
  return Account.fromMap(map['id'] as String, map);
}

MonthlyEntry _parseEntry(dynamic raw) {
  final map = raw as Map<String, dynamic>;
  return MonthlyEntry.fromMap(map['id'] as String, map);
}
