import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/responsive.dart';
import '../../net_worth/ui/design_chip.dart';
import '../data/vault_store.dart';
import '../models/vault_item.dart';

/// Opens the add/edit form as a draggable-feeling modal sheet on mobile, or
/// a centered Modal (matching `manage_accounts_screen.dart`'s add-account
/// dialog and `CashCounterSheet`'s `asModal`) on the wide/web layout.
Future<void> showVaultItemEditorSheet(
  BuildContext context, {
  VaultItem? existing,
  List<VaultAccountRef> accounts = const [],
}) {
  if (context.isWideLayout) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: dialogContext.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: VaultItemEditorSheet(
              existing: existing,
              accounts: accounts,
              asModal: true,
            ),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        VaultItemEditorSheet(existing: existing, accounts: accounts),
  );
}

class VaultItemEditorSheet extends StatefulWidget {
  const VaultItemEditorSheet({
    super.key,
    this.existing,
    this.accounts = const [],
    this.asModal = false,
  });

  final VaultItem? existing;
  final List<VaultAccountRef> accounts;

  /// True when shown as a centered wide/web Modal instead of a mobile bottom
  /// sheet — drops the drag handle and the bottom-sheet-specific outer
  /// chrome (top-only radius, `SafeArea`/`viewInsets` padding), since the
  /// hosting `Dialog` already provides background, shape, and centering.
  final bool asModal;

  @override
  State<VaultItemEditorSheet> createState() => _VaultItemEditorSheetState();
}

class _VaultItemEditorSheetState extends State<VaultItemEditorSheet> {
  late VaultItemKind _kind;
  late final TextEditingController _titleController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _cardNumberController;
  late final TextEditingController _cardholderNameController;
  late final TextEditingController _bodyController;
  String? _linkedAccountId;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _kind = e?.kind ?? VaultItemKind.bankCard;
    _titleController = TextEditingController(text: e?.title ?? '');
    _accountNumberController = TextEditingController(
      text: e?.accountNumber ?? '',
    );
    _cardNumberController = TextEditingController(text: e?.cardNumber ?? '');
    _cardholderNameController = TextEditingController(
      text: e?.cardholderName ?? '',
    );
    _bodyController = TextEditingController(text: e?.body ?? '');
    _linkedAccountId = e?.accountId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _accountNumberController.dispose();
    _cardNumberController.dispose();
    _cardholderNameController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final now = DateTime.now();
    String? orNull(String text) => text.trim().isEmpty ? null : text.trim();

    final item = VaultItem(
      id: widget.existing?.id ?? VaultStore.instance.generateId(),
      kind: _kind,
      title: title,
      accountNumber: _kind == VaultItemKind.bankCard
          ? orNull(_accountNumberController.text)
          : null,
      cardNumber: _kind == VaultItemKind.bankCard
          ? orNull(_cardNumberController.text)
          : null,
      cardholderName: _kind == VaultItemKind.bankCard
          ? orNull(_cardholderNameController.text)
          : null,
      body: _kind == VaultItemKind.note ? orNull(_bodyController.text) : null,
      accountId: _linkedAccountId,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    await VaultStore.instance.upsert(item);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await VaultStore.instance.delete(existing.id);
    if (mounted) Navigator.of(context).pop();
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

    InputDecoration decoration(String hint) => InputDecoration(
      hintText: hint,
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
    );

    Widget labeled(String label, Widget field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(label, style: fieldLabelStyle),
        ),
        field,
      ],
    );

    final core = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.asModal)
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
          _editing ? 'Edit vault item' : 'Add vault item',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            fontFamily: uiFont,
            color: palette.heading,
          ),
        ),
        if (!_editing)
          labeled(
            'Kind',
            Row(
              children: [
                DesignChip(
                  label: 'Bank / Card',
                  active: _kind == VaultItemKind.bankCard,
                  onTap: () => setState(() => _kind = VaultItemKind.bankCard),
                ),
                const SizedBox(width: 8),
                DesignChip(
                  label: 'Note',
                  active: _kind == VaultItemKind.note,
                  onTap: () => setState(() => _kind = VaultItemKind.note),
                ),
              ],
            ),
          ),
        labeled(
          'Title',
          TextField(
            controller: _titleController,
            autofocus: !_editing,
            style: TextStyle(
              fontSize: 13.5,
              fontFamily: uiFont,
              color: palette.heading,
            ),
            decoration: decoration(
              _kind == VaultItemKind.bankCard
                  ? 'e.g. Metrobank Visa'
                  : 'e.g. Wifi password',
            ),
          ),
        ),
        if (_kind == VaultItemKind.bankCard) ...[
          labeled(
            'Account number',
            TextField(
              controller: _accountNumberController,
              style: TextStyle(
                fontSize: 13.5,
                fontFamily: monoFont,
                color: palette.heading,
              ),
              decoration: decoration('Optional'),
            ),
          ),
          labeled(
            'Card number',
            TextField(
              controller: _cardNumberController,
              style: TextStyle(
                fontSize: 13.5,
                fontFamily: monoFont,
                color: palette.heading,
              ),
              decoration: decoration('Optional'),
            ),
          ),
          labeled(
            'Cardholder name',
            TextField(
              controller: _cardholderNameController,
              style: TextStyle(
                fontSize: 13.5,
                fontFamily: uiFont,
                color: palette.heading,
              ),
              decoration: decoration('Optional'),
            ),
          ),
        ] else
          labeled(
            'Note',
            TextField(
              controller: _bodyController,
              maxLines: 4,
              style: TextStyle(
                fontSize: 13.5,
                fontFamily: uiFont,
                color: palette.heading,
              ),
              decoration: decoration('Freeform text'),
            ),
          ),
        if (widget.accounts.isNotEmpty)
          labeled(
            'Linked account (optional)',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DesignChip(
                  label: 'None',
                  active: _linkedAccountId == null,
                  onTap: () => setState(() => _linkedAccountId = null),
                ),
                for (final a in widget.accounts)
                  DesignChip(
                    label: a.name,
                    active: _linkedAccountId == a.id,
                    onTap: () => setState(() => _linkedAccountId = a.id),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              if (_editing) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: AppPalette.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: AppPalette.error,
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    backgroundColor: AppPalette.blueDeep,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_editing ? 'Save' : 'Add item'),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.asModal) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: core,
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: core,
            ),
          ),
        ),
      ),
    );
  }
}
