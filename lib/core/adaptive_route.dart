import 'package:flutter/material.dart';

import 'responsive.dart';

/// A [MaterialPageRoute] on the mobile breakpoint (keeps the native
/// slide-in/out push transition), but an instant, no-animation route on the
/// wide/web breakpoint — pushing a full-screen route there (Milestones, PIN
/// screens, Secure Vault) would otherwise still slide in from the right like
/// a phone screen, which reads as a bug next to the persistent sidebar shell.
Route<T> adaptiveRoute<T>(BuildContext context, WidgetBuilder builder) {
  return buildAdaptiveRoute<T>(wide: context.isWideLayout, builder: builder);
}

/// Same as [adaptiveRoute] but takes a precomputed `wide` flag instead of a
/// [BuildContext] — for call sites (e.g. `vault_entry.dart`) that only know
/// whether to push after several `await`s, by which point the original
/// context may already be unmounted. Callers should read
/// `context.isWideLayout` once, up front, and thread that value through.
Route<T> buildAdaptiveRoute<T>({
  required bool wide,
  required WidgetBuilder builder,
}) {
  if (!wide) return MaterialPageRoute<T>(builder: builder);
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}
