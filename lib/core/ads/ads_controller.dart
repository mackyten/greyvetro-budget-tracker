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
  Future<void> ensureSdkReady() {
    if (!platformSupportsAds) return Future.value();
    return _sdkInit ??= MobileAds.instance.initialize();
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
