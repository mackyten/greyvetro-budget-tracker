import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'cash_counter_sheet.dart';

class MonthDetailScreen extends StatefulWidget {
  const MonthDetailScreen({
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
  State<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends State<MonthDetailScreen> {
  late final Map<String, TextEditingController> _controllers;
  late final TextEditingController _noteController;
  bool _saving = false;

  void _rebuild() => setState(() {});

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
  }

  @override
  void dispose() {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(monthFormat.format(widget.entry.month)),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _SectionHeader('Assets'),
                for (final a in assets) _AccountRow(account: a, controller: _controllers[a.id]!),
                _SectionHeader('Reserved & Liabilities'),
                for (final a in reserved) _AccountRow(account: a, controller: _controllers[a.id]!),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Note', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ),
          _SummaryBar(summary: summary),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
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
    final icon = account.section == AccountSection.asset
        ? Icons.account_balance_wallet_outlined
        : account.reservedKind == ReservedKind.creditCard
            ? Icons.credit_card
            : Icons.savings_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(child: Text(account.name)),
          if (account.cashCounter)
            IconButton(
              icon: const Icon(Icons.calculate_outlined),
              tooltip: 'Count cash',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final total = await showModalBottomSheet<double>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const CashCounterSheet(),
                );
                if (total != null) {
                  controller.text = total.toStringAsFixed(2);
                }
              },
            ),
          SizedBox(
            width: 140,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                prefixText: '₱ ',
                isDense: true,
                border: OutlineInputBorder(),
              ),
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
    final delta = summary.currentMonthSaved;
    final pct = summary.momChangePct;
    final deltaColor = delta == null
        ? null
        : delta >= 0
            ? Colors.green.shade700
            : Colors.red.shade700;

    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryLine('Total Assets', currencyFormat.format(summary.totalAssets)),
            _SummaryLine(
              'Total Reserved & Liabilities',
              currencyFormat.format(summary.totalReservedLiabilities),
            ),
            const Divider(),
            _SummaryLine(
              'Net Savings',
              currencyFormat.format(summary.netSavings),
              bold: true,
            ),
            if (delta != null)
              _SummaryLine(
                'Current month saved',
                '${delta >= 0 ? '+' : ''}${currencyFormat.format(delta)}'
                    '${pct != null ? '  (${percentFormat.format(pct)})' : ''}',
                color: deltaColor,
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value, {this.bold = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
