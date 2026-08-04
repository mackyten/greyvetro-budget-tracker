import 'package:flutter/widgets.dart';

/// Width (logical px) at which the app switches from the mobile
/// single-column shell to the persistent-sidebar wide layout — matches the
/// verified Claude Design artifact's own `viewportWidth < 680` cutoff.
const double kWideBreakpoint = 680;

/// Max width for a single narrow content column in the wide layout (Settings/
/// Export/Help) — the verified design's own `wideNarrow` is 520px for its
/// trimmed-down mockup content; ours runs wider (real Security/PIN cards,
/// not a single placeholder row) so this is deliberately roomier while still
/// keeping the same "left-aligned capped column, not edge-to-edge" intent.
const double kWideNarrowMaxWidth = 640;

extension ResponsiveContext on BuildContext {
  bool get isWideLayout => MediaQuery.sizeOf(this).width >= kWideBreakpoint;
}
