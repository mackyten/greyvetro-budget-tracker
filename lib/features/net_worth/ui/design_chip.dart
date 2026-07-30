import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';

/// Pill-shaped selectable chip used for Section/Kind pickers (Add account)
/// and the theme picker (Settings) — replaces dropdowns/segmented buttons to
/// match the design exactly.
class DesignChip extends StatelessWidget {
  const DesignChip({super.key, required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: active ? AppPalette.blueDeep.withValues(alpha: 0.13) : palette.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: active ? AppPalette.blueDeep : palette.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: manropeFont,
              color: active ? palette.heading : palette.text,
            ),
          ),
        ),
      ),
    );
  }
}
