import 'package:flutter/material.dart';

import '../../../core/pin_lock/biometric_auth.dart';
import '../../../core/pin_lock/pin_store.dart';
import '../../../core/pin_lock/verify_pin_screen.dart';
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
  final pinIsSet = await PinStore.instance.isSet();
  if (!context.mounted) return;

  if (!pinIsSet) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VaultSetupRequiredScreen()),
    );
    return;
  }

  final biometricReady = await PinStore.instance.isBiometricEnabled() &&
      await BiometricAuth.instance.isAvailable();
  if (!context.mounted) return;

  var unlocked = false;
  if (biometricReady) {
    unlocked = await BiometricAuth.instance.authenticate(reason: 'Unlock Secure Vault');
    if (!context.mounted) return;
  }

  if (!unlocked) {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const VerifyPinScreen(title: 'Enter PIN to open Vault'),
      ),
    );
    if (verified != true || !context.mounted) return;
    unlocked = true;
  }

  await VaultStore.instance.loadAll();
  if (!context.mounted) return;

  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => VaultHomeScreen(accounts: accounts)),
  );
}
