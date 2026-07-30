import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/design_tokens.dart';
import 'core/theme_controller.dart';
import 'features/net_worth/data/budget_repository.dart';
import 'features/net_worth/data/firestore_budget_repository.dart';
import 'features/net_worth/data/seed_importer.dart';
import 'features/net_worth/ui/app_shell.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final repository = FirestoreBudgetRepository();
  await importSeedIfEmpty(repository);

  runApp(BudgetTrackerApp(repository: repository));
}

class BudgetTrackerApp extends StatelessWidget {
  BudgetTrackerApp({super.key, required this.repository});

  final BudgetRepository repository;
  final _themeController = ThemeController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Greyvetro Budget Tracker',
          theme: _buildTheme(AppPalette.light, Brightness.light),
          darkTheme: _buildTheme(AppPalette.dark, Brightness.dark),
          themeMode: mode,
          home: AppShell(repository: repository, themeController: _themeController),
        );
      },
    );
  }
}

ThemeData _buildTheme(AppPalette palette, Brightness brightness) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: AppPalette.blueDeep,
    onPrimary: Colors.white,
    secondary: AppPalette.blueDeep,
    onSecondary: Colors.white,
    error: AppPalette.error,
    onError: Colors.white,
    surface: palette.surface,
    onSurface: palette.heading,
    surfaceContainerHighest: palette.surfaceAlt,
    onSurfaceVariant: palette.muted,
    outline: palette.border,
    outlineVariant: palette.border,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: uiFont,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.bg,
    extensions: [palette],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.bg,
      foregroundColor: palette.heading,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
