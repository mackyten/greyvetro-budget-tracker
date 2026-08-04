import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../../features/net_worth/ui/ghost_icon_button.dart';

/// Presentational numeric-PIN screen shared by unlock/create/verify flows.
/// Owns no PIN state itself — the caller tracks the entered digits and
/// re-renders this with an updated [enteredLength]/[errorText].
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.title,
    this.subtitle,
    required this.enteredLength,
    this.pinLength = 4,
    this.errorText,
    required this.onDigit,
    required this.onBackspace,
    this.onCancel,
    this.onBiometricTap,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final int enteredLength;
  final int pinLength;
  final String? errorText;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onCancel;

  /// When set, renders a fingerprint shortcut in the numeric pad's empty
  /// bottom-left slot — pressing it tries biometric auth instead of PIN
  /// digits.
  final VoidCallback? onBiometricTap;

  /// False while a failed-attempt lockout is active: digit and backspace
  /// buttons dim and stop responding. The biometric shortcut deliberately
  /// stays live — lockout throttles PIN *guessing*, and biometrics aren't a
  /// guessable channel.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.bg,
      // The header/dots/numeric-pad used to sit in a bare Column with two
      // Spacer()s absorbing slack — fine as long as content was guaranteed
      // to fit, which stopped being true once the header grew (52px logo +
      // a subtitle on the create/confirm-PIN path). LayoutBuilder +
      // ConstrainedBox(minHeight) + IntrinsicHeight is the standard
      // "centered when it fits, scrollable when it doesn't" combo: it lets
      // the single Expanded below size normally (filling leftover space) on
      // tall-enough screens, while SingleChildScrollView takes over instead
      // of overflowing on short ones.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 54,
                        child: onCancel != null
                            ? Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: GhostIconButton(
                                    icon: Icons.close,
                                    onPressed: onCancel!,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/branding/logo_mark.png',
                                width: 52,
                                height: 52,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: uiFont,
                                  color: palette.heading,
                                ),
                              ),
                              if (subtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    subtitle!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontFamily: uiFont,
                                      color: palette.muted,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < pinLength; i++)
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 120,
                                      ),
                                      width: 16,
                                      height: 16,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: i < enteredLength
                                            ? AppPalette.blueDeep
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: i < enteredLength
                                              ? AppPalette.blueDeep
                                              : palette.border,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(
                                height: 32,
                                child: errorText == null
                                    ? null
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          errorText!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppPalette.error,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _NumericPad(
                        onDigit: onDigit,
                        onBackspace: onBackspace,
                        onBiometricTap: onBiometricTap,
                        enabled: enabled,
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NumericPad extends StatelessWidget {
  const _NumericPad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometricTap,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometricTap;
  final bool enabled;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in row)
                  _PadButton(
                    label: d,
                    onTap: enabled ? () => onDigit(d) : null,
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              onBiometricTap != null
                  ? _PadButton(icon: Icons.fingerprint, onTap: onBiometricTap!)
                  : const SizedBox(width: 72, height: 72),
              _PadButton(
                label: '0',
                onTap: enabled ? () => onDigit('0') : null,
              ),
              _PadButton(
                icon: Icons.backspace_outlined,
                onTap: enabled ? onBackspace : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;

  /// Null renders the button dimmed and inert (lockout state).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Material(
            color: palette.surfaceAlt,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: label != null
                    ? Text(
                        label!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: uiFont,
                          color: palette.heading,
                        ),
                      )
                    : Icon(icon, size: 22, color: palette.heading),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
