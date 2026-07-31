import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/pin_lock/create_pin_screen.dart';
import '../../../core/pin_lock/pin_store.dart';
import '../../../core/pin_lock/verify_pin_screen.dart';
import '../../../core/theme_controller.dart';
import 'design_chip.dart';
import 'ghost_icon_button.dart';
import 'pill_switch.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loadingPin = true;
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final enabled = await PinStore.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _pinEnabled = enabled;
      _loadingPin = false;
    });
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
