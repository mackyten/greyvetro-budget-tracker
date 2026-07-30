import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';

/// Squircle FAB with the design's signature blueDeep→salmon gradient — a
/// standard [FloatingActionButton] can't render a gradient fill, so this is
/// a plain [Material] + [InkWell] instead.
class GradientFab extends StatelessWidget {
  const GradientFab({super.key, required this.onPressed, this.icon = Icons.add});

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppPalette.fabGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppPalette.blueDeep.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
