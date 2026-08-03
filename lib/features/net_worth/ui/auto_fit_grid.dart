import 'package:flutter/material.dart';

/// Approximates the CSS `display:grid;grid-template-columns:repeat(auto-fit,
/// minmax(minItemWidth,1fr))` pattern the wide dashboard design uses for its
/// KPI row and chart grids: as many equal-width columns as fit at
/// [minItemWidth] each, wrapping to a new row when they don't.
class AutoFitGrid extends StatelessWidget {
  const AutoFitGrid({
    super.key,
    required this.children,
    required this.minItemWidth,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (((width + spacing) / (minItemWidth + spacing)).floor())
            .clamp(1, children.length);
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children) SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
