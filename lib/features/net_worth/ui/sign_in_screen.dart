import 'package:flutter/material.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/design_tokens.dart';

/// Shown when no [AuthService] session exists. Sign-in here is separate from
/// (and happens before) the local PIN lock — this gates the Firestore
/// backend, PIN gates the device.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _signingIn = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      await widget.authService.signIn();
      // AuthGate rebuilds from authStateChanges(); nothing else to do here.
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't sign in. Please try again.");
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/branding/app_mark.png', width: 64, height: 64),
              const SizedBox(height: 20),
              Text(
                'Sign in to continue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFamily: uiFont,
                  color: palette.heading,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your net worth data is stored per-account, so signing in '
                'keeps it private to you.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontFamily: uiFont, color: palette.muted),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, fontFamily: uiFont, color: AppPalette.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _signingIn ? null : _signIn,
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.blueDeep,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _signingIn
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login, size: 18),
                label: Text(_signingIn ? 'Signing in…' : 'Continue with Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
