import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// reCAPTCHA v3 site key for App Check on web builds.
///
/// App Check on web has no device attestation — it can only work through a
/// reCAPTCHA challenge, which requires a site key created in the Firebase
/// console (App Check → Apps → the web app → reCAPTCHA v3). Until that key
/// exists, this stays empty and [activateAppCheck] skips web activation
/// entirely rather than crashing web builds with an invalid-key error.
/// The key is a *public* identifier (it ships in the page JS regardless),
/// so committing it here once created is fine.
const String appCheckRecaptchaV3SiteKey = '';

/// Activates Firebase App Check so Firestore requests carry an attestation
/// token proving they come from a genuine build of this app.
///
/// Why: the Firebase config in `firebase_options.dart` is public by design,
/// so without App Check anyone can point a script at this project's
/// Firestore. Security rules still isolate data per-user, so the risk being
/// closed here is scripted abuse / quota burn, not data theft.
///
/// Provider choice per platform:
/// - Android release: Play Integrity (the current-generation attestation
///   API; SafetyNet is deprecated).
/// - macOS release: App Attest, falling back to DeviceCheck automatically
///   on OS versions / configurations where App Attest is unavailable.
/// - Any debug build: the debug provider, so local dev keeps working —
///   Play Integrity / App Attest only pass for store-signed builds. The
///   debug provider prints a token on first run that must be registered in
///   the Firebase console (App Check → Apps → Manage debug tokens).
/// - Web: reCAPTCHA v3, but only once [appCheckRecaptchaV3SiteKey] is set.
///
/// Like `ReminderScheduler.init`, this is startup-critical (`main.dart`
/// awaits it before `runApp()`), so any platform hiccup is swallowed:
/// while App Check is in monitor-only mode, running without a token is
/// strictly better than a blank-screen crash. Tests never hit this — they
/// build `BudgetTrackerApp` directly and skip `main()`.
Future<void> activateAppCheck() async {
  try {
    if (kIsWeb) {
      if (appCheckRecaptchaV3SiteKey.isEmpty) {
        debugPrint('App Check: no reCAPTCHA site key set, skipping web activation.');
        return;
      }
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(appCheckRecaptchaV3SiteKey),
      );
      return;
    }
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (error, stackTrace) {
    debugPrint('App Check activation failed, continuing without it: $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
  }
}
