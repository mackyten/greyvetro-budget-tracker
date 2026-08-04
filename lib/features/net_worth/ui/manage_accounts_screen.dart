import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/responsive.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import 'auto_fit_grid.dart';
import 'design_chip.dart';
import 'ghost_icon_button.dart';
import 'pill_switch.dart';
import 'solid_icon_button.dart';

class ManageAccountsScreen extends StatelessWidget {
  const ManageAccountsScreen({
    super.key,
    required this.repository,
    this.embedded = false,
  });

  final BudgetRepository repository;

  /// True when hosted inline in the wide layout's persistent sidebar shell
  /// (see `home_screen.dart`'s `WideSection.accounts`) instead of pushed as
  /// its own full screen — swaps the back-button header for the design's
  /// `wideHeaderRow` + two-card Assets/Reserved grid. Mobile (`embedded:
  /// false`, the default) is untouched.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (embedded) return _buildWide(context);
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
              child: Row(
                children: [
                  GhostIconButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Accounts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: uiFont,
                        color: palette.heading,
                      ),
                    ),
                  ),
                  SolidIconButton(
                    icon: Icons.add,
                    onPressed: () => _showAddSheet(context, repository),
                  ),
                ],
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
                  final assets = accounts
                      .where((a) => a.section == AccountSection.asset)
                      .toList();
                  final reserved = accounts
                      .where(
                        (a) => a.section == AccountSection.reservedLiability,
                      )
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    children: [
                      const _GroupHeader('Assets'),
                      for (final a in assets)
                        _AccountTile(account: a, repository: repository),
                      const _GroupHeader('Reserved & Liabilities'),
                      for (final a in reserved)
                        _AccountTile(account: a, repository: repository),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWide(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Accounts',
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
                onTap: () => _showAddSheet(context, repository),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Text(
                    '+ Add account',
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
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kWideAccountsMaxWidth,
              ),
              child: StreamBuilder<List<Account>>(
                stream: repository.watchAccounts(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final accounts = List<Account>.from(snap.data!)
                    ..sort((a, b) => a.order.compareTo(b.order));
                  final assets = accounts
                      .where((a) => a.section == AccountSection.asset)
                      .toList();
                  final reserved = accounts
                      .where(
                        (a) => a.section == AccountSection.reservedLiability,
                      )
                      .toList();
                  return AutoFitGrid(
                    minItemWidth: 340,
                    children: [
                      _WideAccountsCard(
                        title: 'Assets',
                        accounts: assets,
                        repository: repository,
                      ),
                      _WideAccountsCard(
                        title: 'Reserved & Liabilities',
                        accounts: reserved,
                        repository: repository,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
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
    final isWide = context.isWideLayout;

    Widget buildForm(BuildContext formContext, StateSetter setSheetState) {
      final isCash =
          section == AccountSection.asset &&
          nameController.text.trim().toLowerCase() == 'cash';
      final palette = formContext.palette;
      final fieldLabelStyle = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        fontFamily: uiFont,
        color: palette.muted,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isWide)
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
              fontFamily: uiFont,
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
            onChanged: (_) => setSheetState(() {}),
            style: TextStyle(
              fontSize: 13.5,
              fontFamily: uiFont,
              color: palette.heading,
            ),
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
                onTap: () =>
                    setSheetState(() => section = AccountSection.asset),
              ),
              const SizedBox(width: 8),
              DesignChip(
                label: 'Reserved / Liability',
                active: section == AccountSection.reservedLiability,
                onTap: () => setSheetState(
                  () => section = AccountSection.reservedLiability,
                ),
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
                  onTap: () => setSheetState(
                    () => reservedKind = ReservedKind.creditCard,
                  ),
                ),
              ],
            ),
          ],
          if (isCash)
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
                            fontFamily: uiFont,
                            color: palette.heading,
                          ),
                        ),
                        Text(
                          'Show a bill/coin calculator shortcut for this account',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: uiFont,
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
                    onPressed: () => Navigator.of(formContext).pop(),
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
                      final id = _uniqueSlug(
                        name,
                        accounts.map((a) => a.id).toSet(),
                      );
                      final order = accounts.isEmpty
                          ? 0
                          : accounts
                                    .map((a) => a.order)
                                    .reduce((a, b) => a > b ? a : b) +
                                1;
                      await repository.addAccount(
                        Account(
                          id: id,
                          name: name,
                          section: section,
                          reservedKind:
                              section == AccountSection.reservedLiability
                              ? reservedKind
                              : null,
                          order: order,
                          cashCounter: isCash ? cashCounter : false,
                        ),
                      );
                      if (formContext.mounted) Navigator.of(formContext).pop();
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
      );
    }

    if (isWide) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: dialogContext.palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
            ),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: SingleChildScrollView(
                child: StatefulBuilder(builder: buildForm),
              ),
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (builderContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(builderContext).viewInsets.bottom,
          ),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(builderContext).size.height * 0.9,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: builderContext.palette.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  child: buildForm(builderContext, setSheetState),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WideAccountsCard extends StatelessWidget {
  const _WideAccountsCard({
    required this.title,
    required this.accounts,
    required this.repository,
  });

  final String title;
  final List<Account> accounts;
  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontFamily: uiFont,
              color: AppPalette.blueDeep,
            ),
          ),
          for (final a in accounts)
            _AccountTile(account: a, repository: repository),
        ],
      ),
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

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.repository});

  final Account account;
  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isCashAccount =
        account.section == AccountSection.asset &&
        account.name.trim().toLowerCase() == 'cash';
    final subtitle = account.reservedKind != null
        ? (account.reservedKind == ReservedKind.creditCard
              ? 'Credit card'
              : 'Reserved fund')
        : (isCashAccount
              ? (account.cashCounter
                    ? 'Cash counter enabled'
                    : 'Cash counter off')
              : null);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
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
                    fontFamily: uiFont,
                    color: account.active ? palette.heading : palette.muted,
                    decoration: account.active
                        ? null
                        : TextDecoration.lineThrough,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: uiFont,
                      color: palette.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (isCashAccount) ...[
            _CashCounterToggle(account: account, repository: repository),
            const SizedBox(width: 6),
          ],
          PillSwitch(
            value: account.active,
            onChanged: (value) =>
                repository.setAccountActive(account.id, value),
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
        color: enabled
            ? AppPalette.blueDeep.withValues(alpha: 0.13)
            : palette.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
            color: enabled ? AppPalette.blueDeep : palette.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () =>
              repository.updateAccount(account.copyWith(cashCounter: !enabled)),
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
