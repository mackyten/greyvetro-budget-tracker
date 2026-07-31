import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design_tokens.dart';
import '../data/budget_repository.dart';
import '../data/export_builder.dart';
import '../data/import_reader.dart';
import 'design_chip.dart';
import 'ghost_icon_button.dart';

enum _ExportFormat { csv, pdf, jsonBackup }

/// Replaces the "Coming soon" `PlaceholderScreen` previously wired to the
/// drawer's Export/Backup row. Export (CSV/PDF/JSON) is read/share-only;
/// Import is the only path that mutates data, and always goes through an
/// explicit diff-summary confirmation first. Both halves only ever touch
/// `Account`/`MonthlyEntry` — never `lib/features/vault/`.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.repository});

  final BudgetRepository repository;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  _ExportFormat _format = _ExportFormat.csv;
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final accounts = await widget.repository.watchAccounts().first;
      final entries = await widget.repository.watchMonthlyEntries().first;
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');

      final File file;
      switch (_format) {
        case _ExportFormat.csv:
          file = File('${dir.path}/net_worth_export_$stamp.csv');
          await file.writeAsString(buildCsv(accounts, entries));
        case _ExportFormat.pdf:
          file = File('${dir.path}/net_worth_export_$stamp.pdf');
          await file.writeAsBytes(await buildPdf(accounts, entries));
        case _ExportFormat.jsonBackup:
          file = File('${dir.path}/net_worth_backup_$stamp.json');
          await file.writeAsString(jsonEncode(buildBackupJson(accounts, entries)));
      }

      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _importing = true);
    try {
      final raw = await File(path).readAsString();
      final outcome = parseBackup(raw);
      if (!mounted) return;

      switch (outcome) {
        case ImportRejected():
          await _showMessage('Cannot import this file', outcome.reason);
        case ImportParsed():
          await _confirmAndApply(outcome);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _showMessage(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _confirmAndApply(ImportParsed parsed) async {
    final existingAccounts = await widget.repository.watchAccounts().first;
    final existingEntries = await widget.repository.watchMonthlyEntries().first;
    if (!mounted) return;

    final existingAccountIds = existingAccounts.map((a) => a.id).toSet();
    final existingEntryIds = existingEntries.map((e) => e.id).toSet();
    final newAccounts = parsed.accounts.where((a) => !existingAccountIds.contains(a.id)).length;
    final overwrittenAccounts = parsed.accounts.length - newAccounts;
    final newEntries = parsed.entries.where((e) => !existingEntryIds.contains(e.id)).length;
    final overwrittenEntries = parsed.entries.length - newEntries;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import backup'),
        content: Text(
          'This backup has ${parsed.accounts.length} account(s) and '
          '${parsed.entries.length} month(s).\n\n'
          'Accounts: $newAccounts new, $overwrittenAccounts overwritten.\n'
          'Months: $newEntries new, $overwrittenEntries overwritten.\n\n'
          'This cannot be undone. Vault items are never affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppPalette.blueDeep),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    for (final account in parsed.accounts) {
      await widget.repository.addAccount(account);
    }
    for (final entry in parsed.entries) {
      await widget.repository.saveMonthlyEntry(entry);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup imported.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fieldLabelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      fontFamily: uiFont,
      color: palette.muted,
    );

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
                      'Export / Backup',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: uiFont,
                        color: palette.heading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text('EXPORT', style: fieldLabelStyle),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      DesignChip(
                        label: 'CSV',
                        active: _format == _ExportFormat.csv,
                        onTap: () => setState(() => _format = _ExportFormat.csv),
                      ),
                      DesignChip(
                        label: 'PDF',
                        active: _format == _ExportFormat.pdf,
                        onTap: () => setState(() => _format = _ExportFormat.pdf),
                      ),
                      DesignChip(
                        label: 'JSON Backup',
                        active: _format == _ExportFormat.jsonBackup,
                        onTap: () => setState(() => _format = _ExportFormat.jsonBackup),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _exporting ? null : _export,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: AppPalette.blueDeep,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_exporting ? 'Preparing…' : 'Export data'),
                  ),
                  const SizedBox(height: 28),
                  Container(height: 1, color: palette.border),
                  const SizedBox(height: 20),
                  Text('IMPORT', style: fieldLabelStyle),
                  const SizedBox(height: 4),
                  Text(
                    'Restore accounts and months from a previously exported JSON '
                    'backup. This will overwrite any accounts/months with matching '
                    'ids. Vault items are never included.',
                    style: TextStyle(fontSize: 12, fontFamily: uiFont, color: palette.muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _importing ? null : _pickAndImport,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: palette.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      foregroundColor: palette.heading,
                    ),
                    child: Text(_importing ? 'Importing…' : 'Import backup'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
