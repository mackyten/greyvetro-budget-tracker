import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import 'design_chip.dart';
import 'gradient_fab.dart';
import 'pill_switch.dart';

class ManageAccountsScreen extends StatelessWidget {
  const ManageAccountsScreen({super.key, required this.repository});

  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Text(
                'Accounts',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFamily: manropeFont,
                  color: palette.heading,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Account>>(
                stream: repository.watchAccounts(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final accounts = List<Account>.from(snap.data!)
                    ..sort((a, b) => a.order.compareTo(b.order));
                  final assets =
                      accounts.where((a) => a.section == AccountSection.asset).toList();
                  final reserved = accounts
                      .where((a) => a.section == AccountSection.reservedLiability)
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
                    children: [
                      const _GroupHeader('Assets'),
                      for (final a in assets) _AccountTile(account: a, repository: repository),
                      const _GroupHeader('Reserved & Liabilities'),
                      for (final a in reserved) _AccountTile(account: a, repository: repository),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: GradientFab(onPressed: () => _showAddSheet(context, repository)),
    );
  }

  Future<void> _showAddSheet(
    BuildContext context,
    BudgetRepository repository,
  ) async {
    final nameController = TextEditingController();
    AccountSection section = AccountSection.asset;
    ReservedKind reservedKind = ReservedKind.reserved;
    bool cashCounter = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final palette = sheetContext.palette;
            final fieldLabelStyle = TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: manropeFont,
              color: palette.muted,
            );
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: palette.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Text(
                            'Add account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              fontFamily: manropeFont,
                              color: palette.heading,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 6),
                            child: Text('Name', style: fieldLabelStyle),
                          ),
                          TextField(
                            controller: nameController,
                            autofocus: true,
                            style: TextStyle(fontSize: 13.5, fontFamily: manropeFont, color: palette.heading),
                            decoration: InputDecoration(
                              hintText: 'e.g. Metrobank Savings',
                              filled: true,
                              fillColor: palette.surfaceAlt,
                              contentPadding: const EdgeInsets.all(11),
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
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 6),
                            child: Text('Section', style: fieldLabelStyle),
                          ),
                          Row(
                            children: [
                              DesignChip(
                                label: 'Asset',
                                active: section == AccountSection.asset,
                                onTap: () => setSheetState(() => section = AccountSection.asset),
                              ),
                              const SizedBox(width: 8),
                              DesignChip(
                                label: 'Reserved / Liability',
                                active: section == AccountSection.reservedLiability,
                                onTap: () =>
                                    setSheetState(() => section = AccountSection.reservedLiability),
                              ),
                            ],
                          ),
                          if (section == AccountSection.reservedLiability) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 14, bottom: 6),
                              child: Text('Kind', style: fieldLabelStyle),
                            ),
                            Row(
                              children: [
                                DesignChip(
                                  label: 'Reserved fund',
                                  active: reservedKind == ReservedKind.reserved,
                                  onTap: () =>
                                      setSheetState(() => reservedKind = ReservedKind.reserved),
                                ),
                                const SizedBox(width: 8),
                                DesignChip(
                                  label: 'Credit card',
                                  active: reservedKind == ReservedKind.creditCard,
                                  onTap: () =>
                                      setSheetState(() => reservedKind = ReservedKind.creditCard),
                                ),
                              ],
                            ),
                          ],
                          if (section == AccountSection.asset)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: palette.surfaceAlt,
                                border: Border.all(color: palette.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cash denomination counter',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: manropeFont,
                                            color: palette.heading,
                                          ),
                                        ),
                                        Text(
                                          'Show a bill/coin calculator shortcut for this account',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: manropeFont,
                                            color: palette.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  PillSwitch(
                                    value: cashCounter,
                                    onChanged: (v) => setSheetState(() => cashCounter = v),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(sheetContext).pop(),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      side: BorderSide(color: palette.border),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      foregroundColor: palette.heading,
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () async {
                                      final name = nameController.text.trim();
                                      if (name.isEmpty) return;
                                      final accounts = await repository.watchAccounts().first;
                                      final id =
                                          _uniqueSlug(name, accounts.map((a) => a.id).toSet());
                                      final order = accounts.isEmpty
                                          ? 0
                                          : accounts.map((a) => a.order).reduce((a, b) => a > b ? a : b) +
                                              1;
                                      await repository.addAccount(
                                        Account(
                                          id: id,
                                          name: name,
                                          section: section,
                                          reservedKind: section == AccountSection.reservedLiability
                                              ? reservedKind
                                              : null,
                                          order: order,
                                          cashCounter:
                                              section == AccountSection.asset ? cashCounter : false,
                                        ),
                                      );
                                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                                    },
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      backgroundColor: AppPalette.blueDeep,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Add account'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _uniqueSlug(String name, Set<String> existing) {
  final base = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  var candidate = base;
  var suffix = 2;
  while (existing.contains(candidate)) {
    candidate = '${base}_$suffix';
    suffix++;
  }
  return candidate;
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          fontFamily: manropeFont,
          color: AppPalette.blueDeep,
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.repository});

  final Account account;
  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final subtitle = account.reservedKind != null
        ? (account.reservedKind == ReservedKind.creditCard ? 'Credit card' : 'Reserved fund')
        : (account.cashCounter ? 'Cash counter enabled' : 'Cash counter off');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: manropeFont,
                    color: account.active ? palette.heading : palette.muted,
                    decoration: account.active ? null : TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, fontFamily: manropeFont, color: palette.muted),
                ),
              ],
            ),
          ),
          if (account.section == AccountSection.asset) ...[
            _CashCounterToggle(account: account, repository: repository),
            const SizedBox(width: 6),
          ],
          PillSwitch(
            value: account.active,
            onChanged: (value) => repository.setAccountActive(account.id, value),
          ),
        ],
      ),
    );
  }
}

class _CashCounterToggle extends StatelessWidget {
  const _CashCounterToggle({required this.account, required this.repository});

  final Account account;
  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = account.cashCounter;
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: enabled ? AppPalette.blueDeep.withValues(alpha: 0.13) : palette.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(color: enabled ? AppPalette.blueDeep : palette.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => repository.updateAccount(account.copyWith(cashCounter: !enabled)),
          child: Icon(
            Icons.calculate,
            size: 16,
            color: enabled ? AppPalette.blueDeep : palette.muted,
          ),
        ),
      ),
    );
  }
}
