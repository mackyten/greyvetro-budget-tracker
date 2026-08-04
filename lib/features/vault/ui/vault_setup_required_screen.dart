import 'package:flutter/material.dart';

import '../../../core/adaptive_route.dart';
import '../../../core/design_tokens.dart';
import '../../../core/pin_lock/create_pin_screen.dart';
import '../../../core/pin_lock/pin_store.dart';
import '../../net_worth/ui/ghost_icon_button.dart';
import '../data/vault_store.dart';
import 'vault_home_screen.dart';

/// Shown when the Vault is opened but no app PIN exists yet — locked in:
/// vault access is blocked entirely until a PIN exists, no "unprotected"
/// fallback, since card numbers don't get a soft-warning default.
class VaultSetupRequiredScreen extends StatelessWidget {
  const VaultSetupRequiredScreen({super.key});

  Future<void> _setUpPin(BuildContext context) async {
    final pin = await Navigator.of(
      context,
    ).push<String>(adaptiveRoute(context, (_) => const CreatePinScreen()));
    if (pin == null || !context.mounted) return;
    await PinStore.instance.setPin(pin);
    await VaultStore.instance.loadAll();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(adaptiveRoute(context, (_) => const VaultHomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: GhostIconButton(
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 48,
                          color: palette.muted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Set up a PIN to use the Vault',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            fontFamily: uiFont,
                            color: palette.heading,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The Secure Vault stores sensitive details like card numbers '
                          'locally on this device. A PIN is required before it can be '
                          'opened at all.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: uiFont,
                            color: palette.muted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => _setUpPin(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.blueDeep,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Set up PIN'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
