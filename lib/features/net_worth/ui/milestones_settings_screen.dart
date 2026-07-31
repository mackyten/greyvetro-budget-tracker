import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../../../core/thousands_input_formatter.dart';
import '../data/net_worth_preferences.dart';
import 'ghost_icon_button.dart';
import 'gradient_fab.dart';

/// Manage net-savings milestone targets — supports multiple simultaneous
/// targets from the start (confirmed). Mirrors `manage_accounts_screen.dart`'s
/// list + FAB + add-sheet structure.
class MilestonesSettingsScreen extends StatefulWidget {
  const MilestonesSettingsScreen({super.key});

  @override
  State<MilestonesSettingsScreen> createState() => _MilestonesSettingsScreenState();
}

class _MilestonesSettingsScreenState extends State<MilestonesSettingsScreen> {
  List<double>? _targets;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final targets = await NetWorthPreferences.instance.getTargets();
    targets.sort();
    if (!mounted) return;
    setState(() => _targets = targets);
  }

  Future<void> _remove(double target) async {
    final targets = List<double>.from(_targets ?? []);
    targets.remove(target);
    await NetWorthPreferences.instance.setTargets(targets);
    await _load();
  }

  Future<void> _add(double target) async {
    final targets = List<double>.from(_targets ?? []);
    if (!targets.contains(target)) targets.add(target);
    await NetWorthPreferences.instance.setTargets(targets);
    await _load();
  }

  Future<void> _showAddSheet() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
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
                    'Add milestone',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      fontFamily: uiFont,
                      color: palette.heading,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 6),
                    child: Text(
                      'Target net savings',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: uiFont,
                        color: palette.muted,
                      ),
                    ),
                  ),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [ThousandsInputFormatter()],
                    style: TextStyle(fontSize: 13.5, fontFamily: monoFont, color: palette.heading),
                    decoration: InputDecoration(
                      hintText: 'e.g. 1,000,000',
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
                    padding: const EdgeInsets.only(top: 20),
                    child: FilledButton(
                      onPressed: () async {
                        final amount = parseAmount(controller.text);
                        if (amount == null || amount <= 0) return;
                        await _add(amount);
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: AppPalette.blueDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add milestone'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final targets = _targets;

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
                      'Milestones',
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
              child: targets == null
                  ? const Center(child: CircularProgressIndicator())
                  : targets.isEmpty
                      ? Center(
                          child: Text(
                            'No milestones yet. Tap + to set a net savings target.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: uiFont, color: palette.muted),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                          children: [
                            for (final target in targets) _MilestoneTile(
                              target: target,
                              onDelete: () => _remove(target),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: GradientFab(onPressed: _showAddSheet),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.target, required this.onDelete});

  final double target;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, size: 18, color: AppPalette.blueDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              currencyFormat.format(target),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: monoFont,
                color: palette.heading,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: palette.muted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
