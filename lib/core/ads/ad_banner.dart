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
  BannerAd? _ad;
  bool _loaded = false;

  /// True once a load has been kicked off for the current ads-on stretch.
  /// Deliberately left true after a failed load so a broken network doesn't
  /// cause a request loop on every rebuild; toggling ads off/on resets it.
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    AdsController.instance.adsEnabled.addListener(_onAdsEnabledChanged);
  }

  @override
  void dispose() {
    AdsController.instance.adsEnabled.removeListener(_onAdsEnabledChanged);
    _ad?.dispose();
    super.dispose();
  }

  void _onAdsEnabledChanged() {
    if (!mounted) return;
    if (!AdsController.instance.adsEnabled.value) {
      // Owner toggled ads off mid-session: drop the loaded ad entirely so
      // it stops rendering/refreshing, and allow a fresh load next time.
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      _requested = false;
    }
    setState(() {});
  }

  Future<void> _load(double availableWidth) async {
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      availableWidth.truncate(),
    );
    if (size == null || !mounted) return;
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
          // No-fill / network failure: stay collapsed rather than showing a
          // blank strip. `_requested` stays true (see its doc comment).
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
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
