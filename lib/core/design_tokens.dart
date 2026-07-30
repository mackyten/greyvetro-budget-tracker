import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Exact design tokens ported from the verified Claude Design artifact
/// (`Greyvetro Budget Tracker.dc.html`) — not Material3-generated colors.
/// Registered on [ThemeData.extensions] so screens read it via
/// `Theme.of(context).extension<AppPalette>()!` and stay in sync with
/// light/dark mode switching.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.heading,
    required this.muted,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color heading;
  final Color muted;

  // Brand/semantic colors are identical across light and dark.
  static const blueDeep = Color(0xFF3E9AC4);
  static const blueLight = Color(0xFF8FD0E8);
  static const ok = Color(0xFF2FA96A);
  static const error = Color(0xFFE0607A);
  static const colorblindBlue = Color(0xFF0072B2);
  static const colorblindOrange = Color(0xFFE69F00);
  static const fabGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blueDeep, Color(0xFFE58D9E)],
  );

  static const light = AppPalette(
    bg: Color(0xFFEEF1F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4F5F7),
    border: Color(0xFFE1E6EC),
    text: Color(0xFF5B6470),
    heading: Color(0xFF2E343D),
    muted: Color(0xFF8A93A0),
  );

  static const dark = AppPalette(
    bg: Color(0xFF12151A),
    surface: Color(0xFF1A1F26),
    surfaceAlt: Color(0xFF222834),
    border: Color(0xFF2C3440),
    text: Color(0xFFA9B2BF),
    heading: Color(0xFFE8ECF1),
    muted: Color(0xFF6B7482),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? text,
    Color? heading,
    Color? muted,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      text: text ?? this.text,
      heading: heading ?? this.heading,
      muted: muted ?? this.muted,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      heading: Color.lerp(heading, other.heading, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Resolving this triggers google_fonts to fetch/cache Poppins and registers
/// it under the family name below — that's why it's a getter, not a const.
final String uiFont = GoogleFonts.poppins().fontFamily!;
const monoFont = 'JetBrains Mono';
