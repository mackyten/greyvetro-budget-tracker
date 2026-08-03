import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'app_user.dart';
import 'auth_service.dart';

/// [AuthService] backed by Firebase Auth + Google Sign-In.
///
/// Interim identity provider until greyvetro-auth-hub is bridged in — see
/// the doc comment on [AuthService] for how that swap stays contained to a
/// new implementation of this interface.
///
/// [initialize] must be awaited once (in `main`) before any other member is
/// used, since `google_sign_in` 7.x requires `GoogleSignIn.instance.initialize`
/// to complete first.
///
/// **Web is a special case**: `google_sign_in_web`'s `authenticate()` always
/// throws — the Google Identity Services SDK only allows signing in through
/// its own rendered button widget, not an imperative call like every other
/// platform supports. Rather than restructure the sign-in UI just for web,
/// [signIn]/[signOut]/[deleteAccount] branch to Firebase Auth's own
/// popup-based flow (`signInWithPopup`/`reauthenticateWithPopup`) on web,
/// which needs no `google_sign_in` involvement at all there.
class FirebaseGoogleAuthService implements AuthService {
  FirebaseGoogleAuthService({fb.FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Future<void> initialize() => kIsWeb ? Future.value() : _googleSignIn.initialize();

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<AppUser> signIn() async {
    if (kIsWeb) return _signInOnWeb();

    final GoogleSignInAccount googleAccount;
    try {
      googleAccount = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Sign-in cancelled.', cancelled: true);
      }
      // clientConfigurationError/providerConfigurationError here almost
      // always means the SHA-1/SHA-256 fingerprint of the build that's
      // running isn't registered against this package name in the Firebase
      // console, or the Google provider isn't enabled there — surface the
      // code/description since "please try again" won't fix a config issue.
      throw AuthException(
        'Google sign-in failed (${e.code.name}'
        '${e.description != null ? ': ${e.description}' : ''}).',
      );
    }

    final idToken = googleAccount.authentication.idToken;
    if (idToken == null) {
      throw const AuthException(
        "Google sign-in didn't return an ID token — check that a Web OAuth "
        'client exists for this Firebase project and google-services.json '
        'includes it.',
      );
    }

    final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
    return _signInWithFirebaseCredential(credential);
  }

  Future<AppUser> _signInOnWeb() async {
    try {
      final userCredential = await _auth.signInWithPopup(fb.GoogleAuthProvider());
      final user = _toAppUser(userCredential.user);
      if (user == null) {
        throw const AuthException('Firebase sign-in succeeded but returned no user.');
      }
      return user;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        throw const AuthException('Sign-in cancelled.', cancelled: true);
      }
      throw AuthException('Firebase sign-in failed (${e.code}): ${e.message ?? 'no details'}');
    }
  }

  Future<AppUser> _signInWithFirebaseCredential(fb.AuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = _toAppUser(userCredential.user);
      if (user == null) {
        throw const AuthException('Firebase sign-in succeeded but returned no user.');
      }
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException('Firebase sign-in failed (${e.code}): ${e.message ?? 'no details'}');
    }
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // Firebase requires a *recent* sign-in before allowing account deletion
    // (`requires-recent-login`) — re-run the same credential flow `signIn()`
    // uses to satisfy that, rather than assuming the existing session is
    // fresh enough.
    if (kIsWeb) {
      await user.reauthenticateWithPopup(fb.GoogleAuthProvider());
    } else {
      final googleAccount = await _googleSignIn.authenticate();
      final idToken = googleAccount.authentication.idToken;
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      await user.reauthenticateWithCredential(credential);
      await _googleSignIn.signOut();
    }
    await user.delete();
  }

  AppUser? _toAppUser(fb.User? user) {
    if (user == null) return null;
    return AppUser(uid: user.uid, displayName: user.displayName, email: user.email);
  }
}
