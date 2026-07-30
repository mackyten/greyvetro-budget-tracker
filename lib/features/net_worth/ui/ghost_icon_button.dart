import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';

/// Bordered square icon button (38x38, radius 12) used for the header
/// hamburger/back/save affordances throughout the design — distinct from
/// Material's borderless [IconButton].
class GhostIconButton extends StatelessWidget {
  const GhostIconButton({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 38,
      height: 38,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Icon(icon, size: 20, color: palette.heading),
        ),
      ),
    );
  }
}
