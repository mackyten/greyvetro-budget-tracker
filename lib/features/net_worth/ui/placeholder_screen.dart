import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import 'ghost_icon_button.dart';

/// Generic placeholder for drawer destinations that don't have a real flow
/// yet (Export/Backup, Help/About) — gives them a home without building out
/// functionality that isn't wired to anything.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.headerTitle,
    required this.icon,
    required this.heading,
    this.subtitle,
    required this.message,
    this.trailing,
  });

  final String headerTitle;
  final IconData icon;
  final String heading;
  final String? subtitle;
  final String message;
  final Widget? trailing;

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
                      headerTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: manropeFont,
                        color: palette.heading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 40, color: palette.muted),
                      const SizedBox(height: 6),
                      Text(
                        heading,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: manropeFont,
                          color: palette.heading,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 12, fontFamily: manropeFont, color: palette.muted),
                        ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, fontFamily: manropeFont, color: palette.muted),
                        ),
                      ),
                      if (trailing != null) ...[const SizedBox(height: 16), trailing!],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
