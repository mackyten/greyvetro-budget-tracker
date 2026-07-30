import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';

/// Custom pill toggle (40x22 track, 18px knob) matching the design exactly —
/// visually distinct from Material's default [Switch].
class PillSwitch extends StatelessWidget {
  const PillSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 22,
        decoration: BoxDecoration(
          color: value ? AppPalette.blueDeep : palette.border,
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
