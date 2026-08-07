import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_controller.dart';

/// Anchored adaptive banner meant to be pinned at the bottom of a layout.
/// Collapses to zero height whenever ads are off (owner toggle), the
/// platform can't render them (macOS/web/tests), or no ad has loaded yet —
/// so layouts can include it unconditionally without reserving space.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  /// Give up after this many failed loads in one ads-on stretch. Failures
  /// here are things like a WebView engine that won't start or no network —
  /// worth a few spaced retries (the device's WebView often becomes usable
  /// seconds after app start), but not an endless request loop that AdMob
  /// would read as suspicious traffic. Toggling ads off/on resets the count.
  static const int _maxAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  BannerAd? _ad;
  bool _loaded = false;

  /// True while a load is in flight or a loaded ad is showing — gates the
  /// build-triggered kickoff so rebuilds don't stack duplicate requests.
  bool _requested = false;

  int _attempts = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    AdsController.instance.adsEnabled.addListener(_onAdsEnabledChanged);
  }

  @override
  void dispose() {
    AdsController.instance.adsEnabled.removeListener(_onAdsEnabledChanged);
    _retryTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  void _onAdsEnabledChanged() {
    if (!mounted) return;
    if (!AdsController.instance.adsEnabled.value) {
      // Owner toggled ads off mid-session: drop the loaded ad entirely so
      // it stops rendering/refreshing, and allow a fresh load next time.
      _retryTimer?.cancel();
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      _requested = false;
      _attempts = 0;
    }
    setState(() {});
  }

  Future<void> _load(double availableWidth) async {
    // Loading while MobileAds.initialize() is still in flight is a known
    // source of spurious "Unable to obtain a JavascriptEngine" failures —
    // wait for it (memoized in the controller, so this is free after the
    // first call).
    await AdsController.instance.ensureSdkReady();
    if (!mounted || !AdsController.instance.adsEnabled.value) return;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      availableWidth.truncate(),
    );
    if (size == null || !mounted) return;
    _attempts += 1;
    final ad = BannerAd(
      adUnitId: AdsController.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'AdBanner failed to load (attempt $_attempts/$_maxAttempts): '
            'code=${error.code} domain=${error.domain} '
            'message=${error.message}',
          );
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
          // Stay collapsed rather than showing a blank strip; retry a few
          // times in case the failure was transient (see _maxAttempts).
          if (_attempts < _maxAttempts) {
            _retryTimer = Timer(_retryDelay * _attempts, () {
              if (!mounted || !AdsController.instance.adsEnabled.value) return;
              // Clearing the gate lets the next build kick off a fresh load
              // with a current layout width.
              setState(() => _requested = false);
            });
          }
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdsController.platformSupportsAds ||
        !AdsController.instance.adsEnabled.value) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_requested) {
          _requested = true;
          _load(constraints.maxWidth);
        }
        final ad = _ad;
        if (!_loaded || ad == null) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        );
      },
    );
  }
}
