import 'package:flutter/material.dart';

import '../../../core/adaptive_route.dart';
import '../../../core/pin_lock/biometric_auth.dart';
import '../../../core/pin_lock/pin_store.dart';
import '../../../core/pin_lock/verify_pin_screen.dart';
import '../../../core/responsive.dart';
import '../data/vault_store.dart';
import '../models/vault_item.dart';
import 'vault_home_screen.dart';
import 'vault_setup_required_screen.dart';

/// Entry gate for the Secure Vault. Locked in: vault access is blocked
/// entirely until a PIN exists — no "unprotected" fallback. v1 only gates at
/// entry (no relock-on-backgrounding while the vault screen is open).
///
/// [accounts] lets the caller (which already has `List<Account>` from the
/// normal repository stream) offer the optional Account-link picker without
/// the vault module itself importing `Account`/`BudgetRepository`.
Future<void> openVault(
  BuildContext context, {
  List<VaultAccountRef> accounts = const [],
}) async {
  // Captured once, up front, instead of re-deriving `Navigator.of(context)`
  // after each await below: `context` here is the tapped drawer row's, and
  // the drawer (and everything in it) gets disposed ~250ms after it closes —
  // long before the user finishes a biometric prompt or PIN entry. The
  // NavigatorState itself outlives that, so it's what subsequent
  // navigation/mounted checks need to key off of. `isWide` is captured
  // alongside it for the same reason `adaptiveRoute` can't just take
  // `context` here — it needs a still-mounted context to read `MediaQuery`.
  final navigator = Navigator.of(context);
  final isWide = context.isWideLayout;

  final pinIsSet = await PinStore.instance.isSet();
  if (!navigator.mounted) return;

  if (!pinIsSet) {
    await navigator.push(
      buildAdaptiveRoute(
        wide: isWide,
        builder: (_) => const VaultSetupRequiredScreen(),
      ),
    );
    return;
  }

  final biometricReady =
      await PinStore.instance.isBiometricEnabled() &&
      await BiometricAuth.instance.isAvailable();
  if (!navigator.mounted) return;

  var unlocked = false;
  if (biometricReady) {
    unlocked = await BiometricAuth.instance.authenticate(
      reason: 'Unlock Secure Vault',
    );
    if (!navigator.mounted) return;
  }

  if (!unlocked) {
    final verified = await navigator.push<bool>(
      buildAdaptiveRoute(
        wide: isWide,
        builder: (_) => const VerifyPinScreen(title: 'Enter PIN to open Vault'),
      ),
    );
    if (verified != true || !navigator.mounted) return;
    unlocked = true;
  }

  await VaultStore.instance.loadAll();
  if (!navigator.mounted) return;

  navigator.push(
    buildAdaptiveRoute(
      wide: isWide,
      builder: (_) => VaultHomeScreen(accounts: accounts),
    ),
  );
}
