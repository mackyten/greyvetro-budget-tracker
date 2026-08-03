import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../models/month_summary.dart';

/// A single month row: badge with the month abbreviation, label/subtitle, and
/// net worth with an optional signed-delta pill — shared by [HomeScreen]'s
/// "Recent snapshots" list and [SnapshotsScreen]'s full list so both stay
/// pixel-identical to the design.
class MonthRowTile extends StatelessWidget {
  const MonthRowTile({
    super.key,
    required this.summary,
    required this.onTap,
    this.selected = false,
  });

  final MonthSummary summary;
  final VoidCallback onTap;

  /// Highlights the row (blueDeep border + tinted background) for the wide
  /// Snapshots split view, where the selected row also drives the inline
  /// detail panel. Unused (and visually inert) on mobile.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final delta = summary.currentMonthSaved;
    final deltaColor = delta == null
        ? palette.muted
        : delta >= 0
            ? AppPalette.ok
            : AppPalette.error;

    final headerStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      fontFamily: uiFont,
      color: palette.heading,
    );
    final subtitleStyle = TextStyle(fontSize: 12, fontFamily: uiFont, color: palette.muted);
    final netStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      fontFamily: monoFont,
      color: palette.heading,
    );
    final deltaStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      fontFamily: monoFont,
      color: deltaColor,
    );

    final badge = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.blueDeep.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        monthAbbrevFormat.format(summary.entry.month).toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          fontFamily: uiFont,
          color: AppPalette.blueDeep,
        ),
      ),
    );

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                monthFormat.format(summary.entry.month),
                style: headerStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (summary.entry.locked) ...[
              const SizedBox(width: 6),
              Icon(Icons.lock, size: 12, color: palette.muted),
            ],
          ],
        ),
        Text(
          'Assets ${currencyFormat.format(summary.totalAssets)} · '
          'Reserved ${currencyFormat.format(summary.totalReservedLiabilities)}',
          style: subtitleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final rightColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            currencyFormat.format(summary.netSavings),
            style: netStyle,
            maxLines: 1,
          ),
        ),
        if (delta != null) ...[
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: deltaColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                formatSignedDelta(delta, summary.momChangePct),
                style: deltaStyle,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? AppPalette.blueDeep.withValues(alpha: 0.05) : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppPalette.blueDeep : palette.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge,
                const SizedBox(width: 12),
                Expanded(flex: 3, child: leftColumn),
                const SizedBox(width: 10),
                Flexible(flex: 2, child: rightColumn),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
