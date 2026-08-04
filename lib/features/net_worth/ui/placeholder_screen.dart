import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/responsive.dart';
import 'ghost_icon_button.dart';

/// Generic placeholder for drawer destinations that don't have a real flow
/// yet (Export/Backup, Help/About) — gives them a home without building out
/// functionality that isn't wired to anything.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.headerTitle,
    required this.icon,
    this.logo,
    required this.heading,
    this.subtitle,
    required this.message,
    this.trailing,
    this.embedded = false,
  });

  final String headerTitle;
  final IconData icon;

  /// When set, replaces the [icon] glyph with a brand image (used by the
  /// Help/About screen to show the real Greyvetro logo instead of a generic
  /// icon).
  final Widget? logo;
  final String heading;
  final String? subtitle;
  final String message;
  final Widget? trailing;

  /// True when hosted inline in the wide layout's persistent sidebar shell
  /// instead of pushed as its own full screen — swaps the centered mobile
  /// layout for the verified design's left-aligned `wideSectionTitle` +
  /// narrow column (`section_help`'s `wideNarrow` has no centering). Mobile
  /// (`embedded: false`, the default) is untouched.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (embedded) return _buildWide(context);
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
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      logo ?? Icon(icon, size: 40, color: palette.muted),
                      const SizedBox(height: 6),
                      Text(
                        heading,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: uiFont,
                          color: palette.heading,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: uiFont,
                            color: palette.muted,
                          ),
                        ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: uiFont,
                            color: palette.muted,
                          ),
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(height: 16),
                        trailing!,
                      ],
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

  Widget _buildWide(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerTitle,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            fontFamily: uiFont,
            color: palette.heading,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kWideNarrowMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  logo ?? Icon(icon, size: 36, color: palette.muted),
                  const SizedBox(height: 10),
                  Text(
                    heading,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: uiFont,
                      color: palette.heading,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: uiFont,
                        color: palette.muted,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: uiFont,
                      color: palette.muted,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 16),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
