import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/responsive.dart';
import '../../net_worth/ui/design_chip.dart';
import '../../net_worth/ui/ghost_icon_button.dart';
import '../../net_worth/ui/gradient_fab.dart';
import '../data/vault_store.dart';
import '../models/vault_item.dart';
import 'vault_item_editor_sheet.dart';

/// The Vault's item list — only ever reached through `openVault()`'s PIN
/// gate. Reuses the net-worth feature's presentational widgets
/// (`DesignChip`, `GhostIconButton`, `GradientFab`) purely for visual
/// consistency; none of those import `BudgetRepository`/`cloud_firestore`,
/// so this doesn't break the vault's local-only constraint.
class VaultHomeScreen extends StatefulWidget {
  const VaultHomeScreen({super.key, this.accounts = const []});

  final List<VaultAccountRef> accounts;

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  VaultItemKind? _filter;

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
              child: Row(
                children: [
                  GhostIconButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Secure Vault',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: uiFont,
                        color: palette.heading,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.isWideLayout
                        ? kWideNarrowMaxWidth
                        : double.infinity,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: Row(
                          children: [
                            DesignChip(
                              label: 'All',
                              active: _filter == null,
                              onTap: () => setState(() => _filter = null),
                            ),
                            const SizedBox(width: 8),
                            DesignChip(
                              label: 'Bank / Card',
                              active: _filter == VaultItemKind.bankCard,
                              onTap: () => setState(
                                () => _filter = VaultItemKind.bankCard,
                              ),
                            ),
                            const SizedBox(width: 8),
                            DesignChip(
                              label: 'Note',
                              active: _filter == VaultItemKind.note,
                              onTap: () =>
                                  setState(() => _filter = VaultItemKind.note),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ValueListenableBuilder<List<VaultItem>>(
                          valueListenable: VaultStore.instance.items,
                          builder: (context, items, _) {
                            final filtered = _filter == null
                                ? List<VaultItem>.from(items)
                                : items
                                      .where((i) => i.kind == _filter)
                                      .toList();
                            filtered.sort(
                              (a, b) => b.updatedAt.compareTo(a.updatedAt),
                            );

                            if (filtered.isEmpty) {
                              return Center(
                                child: Text(
                                  'No vault items yet. Tap + to add one.',
                                  style: TextStyle(
                                    fontFamily: uiFont,
                                    color: palette.muted,
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                14,
                                18,
                                96,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) => _VaultItemTile(
                                item: filtered[index],
                                accounts: widget.accounts,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: GradientFab(
        onPressed: () =>
            showVaultItemEditorSheet(context, accounts: widget.accounts),
      ),
    );
  }
}

class _VaultItemTile extends StatelessWidget {
  const _VaultItemTile({required this.item, required this.accounts});

  final VaultItem item;
  final List<VaultAccountRef> accounts;

  String? get _linkedAccountName {
    final accountId = item.accountId;
    if (accountId == null) return null;
    for (final a in accounts) {
      if (a.id == accountId) return a.name;
    }
    return null;
  }

  String get _subtitle {
    if (item.kind == VaultItemKind.bankCard) {
      final parts = <String>[];
      final cardNumber = item.cardNumber;
      if (cardNumber != null && cardNumber.isNotEmpty) {
        final last4 = cardNumber.length > 4
            ? cardNumber.substring(cardNumber.length - 4)
            : cardNumber;
        parts.add('•••• $last4');
      }
      if (item.cardholderName != null && item.cardholderName!.isNotEmpty) {
        parts.add(item.cardholderName!);
      }
      final linked = _linkedAccountName;
      if (linked != null) parts.add('Linked: $linked');
      return parts.isEmpty ? 'Bank / Card' : parts.join(' · ');
    }
    final body = item.body ?? '';
    return body.isEmpty ? 'Note' : body;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final icon = item.kind == VaultItemKind.bankCard
        ? Icons.credit_card_outlined
        : Icons.notes_outlined;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showVaultItemEditorSheet(
            context,
            existing: item,
            accounts: accounts,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          fontFamily: uiFont,
                          color: palette.heading,
                        ),
                      ),
                      Text(
                        _subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: uiFont,
                          color: palette.muted,
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
    );
  }
}
