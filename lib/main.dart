import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/auth/app_user.dart';
import 'core/auth/auth_gate.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/firebase_google_auth_service.dart';
import 'core/design_tokens.dart';
import 'core/pin_lock/pin_gate.dart';
import 'core/theme_controller.dart';
import 'features/net_worth/data/budget_repository.dart';
import 'features/net_worth/data/firestore_budget_repository.dart';
import 'features/net_worth/data/reminder_scheduler.dart';
import 'features/net_worth/ui/home_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ReminderScheduler.instance.init();

  final authService = FirebaseGoogleAuthService();
  await authService.initialize();

  runApp(BudgetTrackerApp(authService: authService));
}

/// Builds the [BudgetRepository] for a signed-in uid. Overridable (e.g. in
/// tests) to avoid touching real Firestore — mirrors how
/// [FirestoreBudgetRepository] itself takes an injectable `firestore` param.
typedef RepositoryBuilder = BudgetRepository Function(String uid);

/// Runs once per signed-in session before the app is shown — a seam for any
/// one-time-per-session async prep a signed-in user might need. Nothing
/// uses it today: the original spreadsheet-seed import was removed once it
/// had served its one-time purpose for the original owner's account, since
/// it was otherwise copying that data into every new account that signed
/// in. Overridable in tests.
typedef AppPreparer = Future<void> Function(BudgetRepository repository, String uid);

Future<void> _defaultPrepare(BudgetRepository repository, String uid) async {}

class BudgetTrackerApp extends StatelessWidget {
  BudgetTrackerApp({
    super.key,
    required this.authService,
    RepositoryBuilder? repositoryBuilder,
    AppPreparer? prepare,
  }) : repositoryBuilder =
           repositoryBuilder ?? ((uid) => FirestoreBudgetRepository(uid: uid)),
       prepare = prepare ?? _defaultPrepare;

  final AuthService authService;
  final RepositoryBuilder repositoryBuilder;
  final AppPreparer prepare;
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
          home: AuthGate(
            authService: authService,
            builder: (context, user) => _AuthenticatedApp(
              user: user,
              authService: authService,
              themeController: _themeController,
              repositoryBuilder: repositoryBuilder,
              prepare: prepare,
            ),
          ),
        );
      },
    );
  }
}

/// Prepares the signed-in user's repository (migrating any pre-auth data,
/// then seeding on first ever use) before showing the PIN gate + app.
class _AuthenticatedApp extends StatefulWidget {
  const _AuthenticatedApp({
    required this.user,
    required this.authService,
    required this.themeController,
    required this.repositoryBuilder,
    required this.prepare,
  });

  final AppUser user;
  final AuthService authService;
  final ThemeController themeController;
  final RepositoryBuilder repositoryBuilder;
  final AppPreparer prepare;

  @override
  State<_AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<_AuthenticatedApp> {
  late final BudgetRepository _repository = widget.repositoryBuilder(widget.user.uid);
  late final Future<void> _ready = widget.prepare(_repository, widget.user.uid);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return PinGate(
          child: HomeScreen(
            repository: _repository,
            authService: widget.authService,
            themeController: widget.themeController,
          ),
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
