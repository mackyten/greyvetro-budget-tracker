import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';

/// Filled square icon button (38x38, radius 12, blueDeep background) used for
/// primary header actions (Save, Add) — distinct from [GhostIconButton]'s
/// bordered/transparent style, which is reserved for secondary actions.
class SolidIconButton extends StatelessWidget {
  const SolidIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Material(
        color: AppPalette.blueDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: loading ? null : onPressed,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
