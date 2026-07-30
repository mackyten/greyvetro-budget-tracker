import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../data/budget_repository.dart';
import '../data/month_draft_store.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'cash_counter_sheet.dart';
import 'ghost_icon_button.dart';

/// How long to wait after the last keystroke before persisting a local
/// draft — frequent enough that an accidental dismiss loses at most a
/// fraction of a second of typing, infrequent enough to not thrash storage.
const _draftSaveDebounce = Duration(milliseconds: 400);

/// Opens the Month Detail editor as a large, draggable modal sheet (rather
/// than a pushed screen) so it reads as "temporarily editing a record" while
/// keeping Home visible/dimmed behind it.
Future<void> showMonthDetailSheet(
  BuildContext context, {
  required BudgetRepository repository,
  required MonthlyEntry entry,
  required List<Account> accounts,
  required MonthlyEntry? previous,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MonthDetailSheet(
      repository: repository,
      entry: entry,
      accounts: accounts,
      previous: previous,
    ),
  );
}

class MonthDetailSheet extends StatefulWidget {
  const MonthDetailSheet({
    super.key,
    required this.repository,
    required this.entry,
    required this.accounts,
    required this.previous,
  });

  final BudgetRepository repository;
  final MonthlyEntry entry;
  final List<Account> accounts;
  final MonthlyEntry? previous;

  @override
  State<MonthDetailSheet> createState() => _MonthDetailSheetState();
}

class _MonthDetailSheetState extends State<MonthDetailSheet> {
  late final Map<String, TextEditingController> _controllers;
  late final TextEditingController _noteController;
  bool _saving = false;
  Timer? _draftSaveTimer;

  /// Set once the user explicitly taps Save — suppresses the dispose-time
  /// draft flush, since the data is now safely persisted server-side and any
  /// local draft has already been cleared.
  bool _committed = false;

  void _rebuild() {
    setState(() {});
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(_draftSaveDebounce, _persistDraft);
  }

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final a in widget.accounts)
        a.id: TextEditingController(
          text: widget.entry.balances[a.id]?.toStringAsFixed(2) ?? '',
        ),
    };
    _noteController = TextEditingController(text: widget.entry.note ?? '');

    // Every keystroke should recompute the live summary bar, regardless of
    // which account field or the note changed.
    for (final c in _controllers.values) {
      c.addListener(_rebuild);
    }
    _noteController.addListener(_rebuild);

    _restoreDraftIfAny();
  }

  /// Recovers edits from a previous session that never made it to an
  /// explicit Save (e.g. the user backed out by accident) — takes priority
  /// over whatever's already saved for this month, since it's strictly more
  /// recent.
  Future<void> _restoreDraftIfAny() async {
    final draft = await MonthDraftStore.instance.load(widget.entry.id);
    if (draft == null || !mounted) return;
    for (final entry in draft.balances.entries) {
      _controllers[entry.key]?.text = entry.value;
    }
    _noteController.text = draft.note;
  }

  Future<void> _persistDraft() async {
    final balances = {for (final e in _controllers.entries) e.key: e.value.text};
    await MonthDraftStore.instance.save(
      widget.entry.id,
      MonthDraft(balances: balances, note: _noteController.text),
    );
  }

  @override
  void dispose() {
    final hadPendingEdits = _draftSaveTimer?.isActive ?? false;
    _draftSaveTimer?.cancel();
    // Flush the latest keystrokes even if the debounce hadn't fired yet —
    // this is the exact "accidental back tap" moment the draft exists for.
    if (!_committed && hadPendingEdits) {
      final balances = {for (final e in _controllers.entries) e.key: e.value.text};
      MonthDraftStore.instance.save(
        widget.entry.id,
        MonthDraft(balances: balances, note: _noteController.text),
      );
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  MonthlyEntry get _liveEntry {
    final balances = <String, double>{};
    for (final entry in _controllers.entries) {
      final parsed = double.tryParse(entry.value.text);
      if (parsed != null) balances[entry.key] = parsed;
    }
    return MonthlyEntry(
      month: widget.entry.month,
      balances: balances,
      note: _noteController.text,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.saveMonthlyEntry(_liveEntry);
      _committed = true;
      _draftSaveTimer?.cancel();
      await MonthDraftStore.instance.clear(widget.entry.id);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleAccounts = widget.accounts
        .where((a) => a.active || widget.entry.balances.containsKey(a.id))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final assets =
        visibleAccounts.where((a) => a.section == AccountSection.asset);
    final reserved = visibleAccounts
        .where((a) => a.section == AccountSection.reservedLiability);

    final summary = MonthSummary.compute(
      entry: _liveEntry,
      previous: widget.previous,
      accounts: widget.accounts,
    );

    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Material(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: palette.border)),
                  ),
                  child: Row(
                    children: [
                      GhostIconButton(
                        icon: Icons.close,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            monthFormat.format(widget.entry.month),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              fontFamily: uiFont,
                              color: palette.heading,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: Material(
                          color: AppPalette.blueDeep,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _saving ? null : _save,
                            child: _saving
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    children: [
                      _SectionHeader('Assets'),
                      for (final a in assets)
                        _AccountRow(account: a, controller: _controllers[a.id]!),
                      _SectionHeader('Reserved & Liabilities'),
                      for (final a in reserved)
                        _AccountRow(account: a, controller: _controllers[a.id]!),
                      Padding(
                        padding: const EdgeInsets.only(top: 18, bottom: 6),
                        child: Text(
                          'NOTE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            fontFamily: uiFont,
                            color: AppPalette.blueDeep,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextField(
                          controller: _noteController,
                          maxLines: 2,
                          style: TextStyle(fontSize: 13, fontFamily: uiFont, color: palette.heading),
                          decoration: InputDecoration(
                            hintText: 'Optional note about this month',
                            filled: true,
                            fillColor: palette.surfaceAlt,
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: palette.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: palette.border),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _SummaryBar(summary: summary),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          fontFamily: uiFont,
          color: AppPalette.blueDeep,
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.controller});

  final Account account;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final icon = account.section == AccountSection.asset
        ? Icons.account_balance_wallet_outlined
        : account.reservedKind == ReservedKind.creditCard
            ? Icons.credit_card_outlined
            : Icons.savings_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              border: Border.all(color: palette.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: palette.muted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: uiFont,
                color: palette.heading,
              ),
            ),
          ),
          if (account.cashCounter) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              height: 28,
              child: Material(
                color: palette.surfaceAlt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: palette.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final total = await showModalBottomSheet<double>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const CashCounterSheet(),
                    );
                    if (total != null) {
                      controller.text = total.toStringAsFixed(2);
                    }
                  },
                  child: const Icon(Icons.calculate, size: 16, color: AppPalette.blueDeep),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Container(
            width: 126,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              border: Border.all(color: palette.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text('₱', style: TextStyle(fontSize: 12, fontFamily: monoFont, color: palette.muted)),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: monoFont,
                      color: palette.heading,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final delta = summary.currentMonthSaved;
    final deltaColor = delta == null
        ? palette.muted
        : delta >= 0
            ? AppPalette.ok
            : AppPalette.error;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SummaryLine('Total Assets', currencyFormat.format(summary.totalAssets)),
          _SummaryLine(
            'Reserved & Liabilities',
            currencyFormat.format(summary.totalReservedLiabilities),
          ),
          Container(height: 1, color: palette.border, margin: const EdgeInsets.symmetric(vertical: 6)),
          _SummaryLine(
            'Net Savings',
            currencyFormat.format(summary.netSavings),
            bold: true,
          ),
          if (delta != null)
            _SummaryLine(
              'Current month saved',
              formatSignedDelta(delta, summary.momChangePct),
              color: deltaColor,
              small: true,
            ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value, {this.bold = false, this.small = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final bool small;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = TextStyle(
      fontSize: bold ? 14 : (small ? 12 : 12.5),
      fontWeight: bold ? FontWeight.w800 : (small ? FontWeight.w700 : FontWeight.normal),
      fontFamily: uiFont,
      color: color ?? (bold ? palette.heading : palette.text),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style.copyWith(fontFamily: monoFont)),
        ],
      ),
    );
  }
}
