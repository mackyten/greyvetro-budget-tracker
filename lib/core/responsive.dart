import 'package:flutter/widgets.dart';

/// Width (logical px) at which the app switches from the mobile
/// single-column shell to the persistent-sidebar wide layout — matches the
/// verified Claude Design artifact's own `viewportWidth < 680` cutoff.
const double kWideBreakpoint = 680;

extension ResponsiveContext on BuildContext {
  bool get isWideLayout => MediaQuery.sizeOf(this).width >= kWideBreakpoint;
}
