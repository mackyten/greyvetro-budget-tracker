import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/design_tokens.dart';
import '../../../core/pin_lock/biometric_auth.dart';
import '../../../core/pin_lock/create_pin_screen.dart';
import '../../../core/pin_lock/pin_store.dart';
import '../../../core/pin_lock/verify_pin_screen.dart';
import '../../../core/theme_controller.dart';
import '../../vault/data/vault_store.dart';
import '../data/budget_repository.dart';
import '../data/net_worth_preferences.dart';
import 'design_chip.dart';
import 'ghost_icon_button.dart';
import 'milestones_settings_screen.dart';
import 'pill_switch.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.repository,
    required this.authService,
  });

  final ThemeController themeController;
  final BudgetRepository repository;
  final AuthService authService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loadingPin = true;
  bool _pinEnabled = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _deletingAccount = false;

  final _inflationRateController = TextEditingController();
  Timer? _inflationSaveTimer;

  @override
  void initState() {
    super.initState();
    _loadPinState();
    _loadInflationRate();
  }

  Future<void> _loadInflationRate() async {
    final rate = await NetWorthPreferences.instance.getAnnualInflationRate();
    if (!mounted) return;
    _inflationRateController.text = rate == 0 ? '' : (rate * 100).toStringAsFixed(1);
  }

  void _onInflationRateChanged(String text) {
    _inflationSaveTimer?.cancel();
    _inflationSaveTimer = Timer(const Duration(milliseconds: 500), () {
      final percent = double.tryParse(text) ?? 0;
      NetWorthPreferences.instance.setAnnualInflationRate(percent / 100);
    });
  }

  @override
  void dispose() {
    _inflationSaveTimer?.cancel();
    _inflationRateController.dispose();
    super.dispose();
  }

  Future<void> _loadPinState() async {
    final enabled = await PinStore.instance.isEnabled();
    final biometricAvailable = await BiometricAuth.instance.isAvailable();
    final biometricEnabled = await PinStore.instance.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _pinEnabled = enabled;
      _biometricAvailable = biometricAvailable;
      _biometricEnabled = biometricEnabled;
      _loadingPin = false;
    });
  }

  Future<void> _onBiometricToggle(bool value) async {
    await PinStore.instance.setBiometricEnabled(value);
    if (mounted) setState(() => _biometricEnabled = value);
  }

  Future<void> _onPinToggle(bool value) async {
    if (value) {
      if (await PinStore.instance.isSet()) {
        await PinStore.instance.setEnabled(true);
        if (mounted) setState(() => _pinEnabled = true);
        return;
      }
      if (!mounted) return;
      final newPin = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CreatePinScreen()),
      );
      if (newPin == null || !mounted) return;
      await PinStore.instance.setPin(newPin);
      if (mounted) setState(() => _pinEnabled = true);
    } else {
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const VerifyPinScreen(title: 'Enter PIN to disable lock'),
        ),
      );
      if (verified != true || !mounted) return;
      await PinStore.instance.setEnabled(false);
      if (mounted) setState(() => _pinEnabled = false);
    }
  }

  Future<void> _changePin() async {
    final verified = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const VerifyPinScreen()));
    if (verified != true || !mounted) return;
    final newPin = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const CreatePinScreen()));
    if (newPin == null) return;
    await PinStore.instance.setPin(newPin);
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your synced accounts and monthly '
          'entries, and clears anything stored only on this device (Secure '
          'Vault, PIN). This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _deletingAccount = true);
    try {
      // Firestore data first — its security rules need an intact
      // `request.auth` to allow the delete, so this has to happen before
      // authService.deleteAccount() removes the identity it's keyed on.
      await widget.repository.deleteAllData();
      await VaultStore.instance.clearAll();
      await PinStore.instance.clear();
      await widget.authService.deleteAccount();
      if (!mounted) return;
      // AuthGate (above this pushed route) has already swapped to
      // SignInScreen from authStateChanges(); pop back to it.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't delete your account. Please try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
                      'Settings',
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                children: [
                  _SectionLabel('Appearance'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: widget.themeController,
                        builder: (context, mode, _) => Row(
                          children: [
                            DesignChip(
                              label: 'Light',
                              active: mode == ThemeMode.light,
                              onTap: () => widget.themeController.value = ThemeMode.light,
                            ),
                            const SizedBox(width: 8),
                            DesignChip(
                              label: 'Dark',
                              active: mode == ThemeMode.dark,
                              onTap: () => widget.themeController.value = ThemeMode.dark,
                            ),
                            const SizedBox(width: 8),
                            DesignChip(
                              label: 'System',
                              active: mode == ThemeMode.system,
                              onTap: () => widget.themeController.value = ThemeMode.system,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel('Security'),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(14),
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
                                'PIN lock',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: uiFont,
                                  color: palette.heading,
                                ),
                              ),
                              Text(
                                'Require a PIN to open the app',
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
                        _loadingPin
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : PillSwitch(value: _pinEnabled, onChanged: _onPinToggle),
                      ],
                    ),
                  ),
                  if (!_loadingPin && _pinEnabled) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _changePin,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: palette.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Change PIN',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: uiFont,
                                    color: palette.heading,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 20, color: palette.muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
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
                                    'Use biometrics',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: uiFont,
                                      color: palette.heading,
                                    ),
                                  ),
                                  Text(
                                    'Unlock with fingerprint/face instead of the PIN',
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
                            PillSwitch(value: _biometricEnabled, onChanged: _onBiometricToggle),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),
                  _SectionLabel('Preferences'),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      border: Border.all(color: palette.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Currency & locale',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: uiFont,
                            color: palette.muted,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: palette.border,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Coming soon',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              fontFamily: uiFont,
                              color: palette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      border: Border.all(color: palette.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Inflation rate (annual %)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: uiFont,
                              color: palette.heading,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 64,
                          child: TextField(
                            controller: _inflationRateController,
                            onChanged: _onInflationRateChanged,
                            textAlign: TextAlign.end,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(fontSize: 13.5, fontFamily: monoFont, color: palette.heading),
                            decoration: InputDecoration(
                              hintText: '0.0',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              filled: true,
                              fillColor: palette.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: palette.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: palette.border),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MilestonesSettingsScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: palette.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Milestones',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: uiFont,
                                  color: palette.heading,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 20, color: palette.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel('Account'),
                  const SizedBox(height: 4),
                  Material(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _deletingAccount ? null : _confirmDeleteAccount,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
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
                                    'Delete my account',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: uiFont,
                                      color: AppPalette.error,
                                    ),
                                  ),
                                  Text(
                                    'Erases synced data and everything stored on this device',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: uiFont,
                                      color: palette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_deletingAccount)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Icon(Icons.chevron_right, size: 20, color: palette.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        fontFamily: uiFont,
        color: AppPalette.blueDeep,
      ),
    );
  }
}
