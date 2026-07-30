import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/theme_controller.dart';
import 'design_chip.dart';
import 'ghost_icon_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.themeController});

  final ThemeController themeController;

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
                        valueListenable: themeController,
                        builder: (context, mode, _) => Row(
                          children: [
                            DesignChip(
                              label: 'Light',
                              active: mode == ThemeMode.light,
                              onTap: () => themeController.value = ThemeMode.light,
                            ),
                            const SizedBox(width: 8),
                            DesignChip(
                              label: 'Dark',
                              active: mode == ThemeMode.dark,
                              onTap: () => themeController.value = ThemeMode.dark,
                            ),
                            const SizedBox(width: 8),
                            DesignChip(
                              label: 'System',
                              active: mode == ThemeMode.system,
                              onTap: () => themeController.value = ThemeMode.system,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
