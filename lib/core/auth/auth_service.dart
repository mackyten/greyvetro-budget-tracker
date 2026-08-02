import 'app_user.dart';

/// Identity boundary for the app. Kept separate from any specific provider
/// SDK — mirrors why [BudgetRepository] hides Firestore behind an interface.
///
/// Today [FirebaseGoogleAuthService] is the only implementation. When
/// greyvetro-auth-hub (Keycloak) is wired in (see TASKS.md), it becomes a
/// second implementation that runs the OIDC flow against auth-hub, exchanges
/// the access token for a Firebase custom token via a backend bridge, and
/// calls `signInWithCustomToken` instead of Google Sign-In — still ending in
/// a Firebase Auth session, so [AppUser.uid] and everything downstream
/// (Firestore rules, `FirestoreBudgetRepository`) stay unchanged. Swapping
/// providers is then just swapping which [AuthService] `main.dart`
/// constructs.
abstract class AuthService {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signIn();

  Future<void> signOut();

  /// Permanently deletes the signed-in identity itself (not the user's
  /// Firestore data — callers wipe that separately via
  /// `BudgetRepository.deleteAllData()` first, since Firestore's security
  /// rules require an intact `request.auth` to allow the delete). Leaves the
  /// caller signed out, same as [signOut].
  Future<void> deleteAccount();
}
