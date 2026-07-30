import 'package:flutter/material.dart';

/// App-wide theme mode override. Held at the [MaterialApp] root and listened
/// to from there so switching it in Settings live-updates the whole app.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.value = ThemeMode.system]);
}
