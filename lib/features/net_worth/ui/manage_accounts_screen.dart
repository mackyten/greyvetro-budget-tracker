import 'package:flutter/material.dart';

import '../data/budget_repository.dart';
import '../models/account.dart';

class ManageAccountsScreen extends StatelessWidget {
  const ManageAccountsScreen({super.key, required this.repository});

  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage accounts')),
      body: StreamBuilder<List<Account>>(
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
            children: [
              const _GroupHeader('Assets'),
              for (final a in assets) _AccountTile(account: a, repository: repository),
              const _GroupHeader('Reserved & Liabilities'),
              for (final a in reserved) _AccountTile(account: a, repository: repository),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, repository),
        tooltip: 'Add account',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    BudgetRepository repository,
  ) async {
    final nameController = TextEditingController();
    AccountSection section = AccountSection.asset;
    ReservedKind reservedKind = ReservedKind.reserved;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AccountSection>(
                    initialValue: section,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: const [
                      DropdownMenuItem(
                        value: AccountSection.asset,
                        child: Text('Asset'),
                      ),
                      DropdownMenuItem(
                        value: AccountSection.reservedLiability,
                        child: Text('Reserved & Liability'),
                      ),
                    ],
                    onChanged: (v) => setDialogState(() => section = v!),
                  ),
                  if (section == AccountSection.reservedLiability) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ReservedKind>(
                      initialValue: reservedKind,
                      decoration: const InputDecoration(labelText: 'Kind'),
                      items: const [
                        DropdownMenuItem(
                          value: ReservedKind.reserved,
                          child: Text('Reserved fund'),
                        ),
                        DropdownMenuItem(
                          value: ReservedKind.creditCard,
                          child: Text('Credit card'),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => reservedKind = v!),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final accounts = await repository.watchAccounts().first;
                    final id = _uniqueSlug(name, accounts.map((a) => a.id).toSet());
                    final order = accounts.isEmpty
                        ? 0
                        : accounts.map((a) => a.order).reduce((a, b) => a > b ? a : b) + 1;
                    await repository.addAccount(
                      Account(
                        id: id,
                        name: name,
                        section: section,
                        reservedKind:
                            section == AccountSection.reservedLiability ? reservedKind : null,
                        order: order,
                      ),
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Add'),
                ),
              ],
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

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.repository});

  final Account account;
  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        account.name,
        style: account.active ? null : const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      subtitle: account.reservedKind != null
          ? Text(account.reservedKind == ReservedKind.creditCard ? 'Credit card' : 'Reserved fund')
          : null,
      trailing: Switch(
        value: account.active,
        onChanged: (value) => repository.setAccountActive(account.id, value),
      ),
    );
  }
}
