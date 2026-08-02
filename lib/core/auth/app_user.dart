/// Provider-agnostic identity. Every [AuthService] implementation — direct
/// Firebase Auth today, a greyvetro-auth-hub-bridged one later — maps its own
/// user type down to this, so the rest of the app never imports a provider
/// SDK's user class directly.
class AppUser {
  const AppUser({required this.uid, this.displayName, this.email});

  /// Firebase Auth uid. Also what Firestore's `request.auth.uid` sees and
  /// what `users/{uid}/...` document paths are keyed on.
  final String uid;
  final String? displayName;
  final String? email;
}
