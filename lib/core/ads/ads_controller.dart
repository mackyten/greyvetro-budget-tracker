import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/app_user.dart';

/// Central switchboard for the app's ads. Follows the same singleton
/// `instance` pattern as [PinStore]/[VaultStore] so any screen can reach it
/// without plumbing.
///
/// The rules it encodes:
/// - Regular users always have ads on. No toggle, no opt-out.
/// - The owner account ([ownerEmail]) gets a persisted on/off toggle in
///   Settings, defaulting to **off**. Interacting with your own live ads
///   violates AdMob policy, so the owner needs to use the app day-to-day
///   with ads hidden — while still being able to flip them on to preview
///   exactly what real users see.
/// - The Mobile Ads SDK is only ever initialized on platforms that support
///   it ([platformSupportsAds]) and only once ads are actually enabled, so
///   ads-off sessions never pay its startup/network cost.
class AdsController {
  AdsController._();

  static final AdsController instance = AdsController._();

  /// The developer/owner account that is allowed to toggle ads off.
  static const String ownerEmail = 'markangelosabado10@gmail.com';

  /// SharedPreferences key holding the owner's toggle choice. Per-device by
  /// nature (ads state isn't worth a Firestore round-trip).
  static const String _ownerAdsEnabledKey = 'ads.ownerAdsEnabled';

  /// Whether the google_mobile_ads SDK exists on this platform at all —
  /// Android/iOS only. macOS and web builds still compile the ads code, but
  /// [AdBanner] collapses to nothing and the SDK is never touched there.
  static bool get platformSupportsAds =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Logical "should this user see ads" state. [AdBanner] listens to this
  /// (further gated on [platformSupportsAds]); the owner-only Settings
  /// toggle binds to it directly, so the owner's choice stays visible and
  /// editable even on platforms that can't render ads.
  final ValueNotifier<bool> adsEnabled = ValueNotifier<bool>(false);

  bool _isOwner = false;

  /// True when the signed-in user is [ownerEmail] — gates the Settings
  /// toggle. Set synchronously by [configureForUser] before its first
  /// await, so it's reliable by the time any screen builds.
  bool get isOwner => _isOwner;

  /// Case-insensitive, whitespace-tolerant owner check, split out so the
  /// matching rule itself is unit-testable.
  static bool isOwnerEmail(String? email) =>
      email != null && email.trim().toLowerCase() == ownerEmail;

  /// Called once per signed-in session (from `_AuthenticatedApp`): decides
  /// the ads state for [user]. Non-owners always get ads; the owner gets
  /// their persisted toggle choice, defaulting to off.
  Future<void> configureForUser(AppUser? user) async {
    _isOwner = isOwnerEmail(user?.email);
    if (!_isOwner) {
      adsEnabled.value = true;
    } else {
      final prefs = await SharedPreferences.getInstance();
      adsEnabled.value = prefs.getBool(_ownerAdsEnabledKey) ?? false;
    }
    if (adsEnabled.value) await ensureSdkReady();
  }

  /// Owner-only: flips ads for this session and persists the choice for
  /// future launches. Silently ignored for anyone else — the toggle is
  /// never shown to them, but defense-in-depth costs nothing here.
  Future<void> setOwnerAdsEnabled(bool value) async {
    if (!_isOwner) return;
    adsEnabled.value = value;
    if (value) await ensureSdkReady();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ownerAdsEnabledKey, value);
  }

  Future<void>? _sdkInit;

  /// Initializes the Mobile Ads SDK exactly once, memoizing the future so
  /// concurrent callers (session configure + a banner about to load) all
  /// await the *same* initialization. [AdBanner] awaits this before every
  /// load — requesting an ad while initialize() is still in flight is a
  /// known source of "Unable to obtain a JavascriptEngine" failures.
  ///
  /// Gates on [_gatherConsent] first: Google's AdMob program policies
  /// require a UMP (User Messaging Platform) consent flow to run — and
  /// consent to be obtained where required — before any ad request is made
  /// to EEA/UK/Swiss users. `canRequestAds()` reflects that outcome, so a
  /// user who hasn't completed a required consent flow simply never gets
  /// the SDK initialized and never sees an ad.
  Future<void> ensureSdkReady() {
    if (!platformSupportsAds) return Future.value();
    return _sdkInit ??= _initializeWithConsent();
  }

  Future<void> _initializeWithConsent() async {
    await _gatherConsent();
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
  }

  /// Runs the UMP consent info update and, if the user is in a region where
  /// it's required (EEA/UK/regulated US states), shows the consent form.
  /// No-ops (completes immediately) everywhere else. Failures are swallowed
  /// the same way [activateAppCheck] swallows platform hiccups — consent
  /// gathering that can't complete should never crash the app; it just
  /// means [ConsentInformation.canRequestAds] stays false and no ad loads.
  Future<void> _gatherConsent() {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null && kDebugMode) {
            debugPrint('UMP consent form error: ${formError.message}');
          }
          if (!completer.isCompleted) completer.complete();
        });
      },
      (formError) {
        if (kDebugMode) {
          debugPrint('UMP consent info update failed: ${formError.message}');
        }
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  /// Whether the privacy-options re-entry point (Settings → "Ad privacy
  /// options") must be shown. Google requires this for any user whose
  /// consent was gathered under UMP, so they can revisit their choice —
  /// distinct from the owner's ads on/off toggle, and shown to *all* users
  /// (not just the owner) when applicable.
  Future<bool> privacyOptionsRequired() async {
    if (!platformSupportsAds) return false;
    final status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  /// Re-shows the privacy options form so a user can change or withdraw
  /// consent after the fact, per UMP policy.
  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError != null && kDebugMode) {
        debugPrint('UMP privacy options form error: ${formError.message}');
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// Banner ad unit ID for the current platform. Debug builds always use
  /// Google's public *test* IDs (safe to click, never pay) so day-to-day
  /// development can't trip AdMob's invalid-traffic policy; release builds
  /// use the real `home_bottom_banner` unit. The iOS release value is still
  /// the test ID — there is no iOS target yet, so create an iOS app + ad
  /// unit in the AdMob console if one is ever added.
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/9214589741'
          : 'ca-app-pub-3940256099942544/2435281174';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-2625609837542116/2963766721'
        : 'ca-app-pub-3940256099942544/2435281174';
  }
}
