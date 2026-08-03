import 'package:flutter/material.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/design_tokens.dart';

/// Shown when no [AuthService] session exists. Sign-in here is separate from
/// (and happens before) the local PIN lock — this gates the Firestore
/// backend, PIN gates the device.
///
/// This is the *only* gate screen — it appears identically for a brand-new
/// install and for a returning-but-signed-out user, so copy here must never
/// assume prior use (no "welcome back").
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
    } on AuthException catch (e) {
      debugPrint('Sign-in failed: $e');
      if (!mounted) return;
      // A user-initiated cancel (closed the account picker) isn't a failure
      // worth alarming them with.
      if (!e.cancelled) setState(() => _error = e.message);
    } catch (e, stackTrace) {
      debugPrint('Sign-in failed: $e\n$stackTrace');
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
      backgroundColor: palette.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _Hero(palette: palette),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                child: Column(
                  children: [
                    Text(
                      'GREYVETRO',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        fontFamily: uiFont,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        fontFamily: uiFont,
                        color: palette.heading,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: AppPalette.fabGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Track your net worth. Understand your growth.\n'
                      'All your data, private and secure.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, height: 1.4, fontFamily: uiFont, color: palette.muted),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TrustBadge(icon: Icons.verified_user_outlined, label: 'Private\nby design'),
                        _BadgeDivider(color: palette.border),
                        _TrustBadge(icon: Icons.lock_outline, label: 'Secure\nand encrypted'),
                        _BadgeDivider(color: palette.border),
                        _TrustBadge(icon: Icons.trending_up, label: 'Your data,\nyour control'),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, fontFamily: uiFont, color: AppPalette.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _signingIn ? null : _signIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.blueDeep,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(6),
                              child: _signingIn
                                  ? const CircularProgressIndicator(strokeWidth: 2, color: AppPalette.blueDeep)
                                  : Image.asset('assets/branding/google_g.png'),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _signingIn ? 'Signing in…' : 'Continue with Google',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: uiFont,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: palette.muted),
                        const SizedBox(width: 6),
                        Text(
                          'We only use this to sign you in — nothing is ever posted.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, fontFamily: uiFont, color: palette.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.blueDeep.withValues(alpha: 0.16),
              palette.bg,
              AppPalette.pinkDeep.withValues(alpha: 0.14),
            ],
          ),
        ),
        child: Center(
          child: Image.asset('assets/branding/logo_mark.png', width: 108, height: 108),
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: palette.surfaceAlt, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: AppPalette.blueDeep),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontFamily: uiFont, color: palette.text, height: 1.3),
        ),
      ],
    );
  }
}

class _BadgeDivider extends StatelessWidget {
  const _BadgeDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(width: 1, height: 32, color: color),
    );
  }
}
