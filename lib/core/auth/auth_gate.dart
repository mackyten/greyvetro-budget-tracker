import 'package:flutter/material.dart';

import '../../features/net_worth/ui/sign_in_screen.dart';
import 'app_user.dart';
import 'auth_service.dart';

/// Shows [SignInScreen] while signed out, otherwise builds [child] for the
/// signed-in [AppUser]. Swapping identity providers later only means
/// constructing a different [AuthService] — this widget doesn't change.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authService, required this.builder});

  final AuthService authService;
  final Widget Function(BuildContext context, AppUser user) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: authService.authStateChanges(),
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return SignInScreen(authService: authService);
        }
        return builder(context, user);
      },
    );
  }
}
