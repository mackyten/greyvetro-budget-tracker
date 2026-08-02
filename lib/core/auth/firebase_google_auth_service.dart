import 'package:firebase_auth/firebase_auth.dart' as fb;
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
class FirebaseGoogleAuthService implements AuthService {
  FirebaseGoogleAuthService({fb.FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Future<void> initialize() => _googleSignIn.initialize();

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<AppUser> signIn() async {
    final googleAccount = await _googleSignIn.authenticate();
    final idToken = googleAccount.authentication.idToken;
    final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    final user = _toAppUser(userCredential.user);
    if (user == null) {
      throw StateError('Firebase sign-in succeeded but returned no user.');
    }
    return user;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  AppUser? _toAppUser(fb.User? user) {
    if (user == null) return null;
    return AppUser(uid: user.uid, displayName: user.displayName, email: user.email);
  }
}
