import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetro_ledger/core/ads/ads_controller.dart';
import 'package:vetro_ledger/core/auth/app_user.dart';

/// Pure-logic tests for the ads switchboard: who counts as the owner, who
/// gets ads, and how the owner's toggle persists. The Mobile Ads SDK itself
/// is never touched here — `platformSupportsAds` is false on the test host,
/// so `_ensureSdkInitialized` is a no-op by design.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owner = AppUser(uid: 'owner-uid', email: 'markangelosabado10@gmail.com');
  const regular = AppUser(uid: 'other-uid', email: 'someone@example.com');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('isOwnerEmail', () {
    test('matches the owner email exactly', () {
      expect(AdsController.isOwnerEmail('markangelosabado10@gmail.com'), isTrue);
    });

    test('is case-insensitive and trims whitespace', () {
      expect(
        AdsController.isOwnerEmail('  MarkAngeloSabado10@Gmail.com  '),
        isTrue,
      );
    });

    test('rejects other emails and null', () {
      expect(AdsController.isOwnerEmail('someone@example.com'), isFalse);
      expect(AdsController.isOwnerEmail(null), isFalse);
      // A lookalike with the owner address embedded must not match.
      expect(
        AdsController.isOwnerEmail('markangelosabado10@gmail.com.evil.com'),
        isFalse,
      );
    });
  });

  group('configureForUser', () {
    test('regular users always get ads on and no owner powers', () async {
      await AdsController.instance.configureForUser(regular);
      expect(AdsController.instance.adsEnabled.value, isTrue);
      expect(AdsController.instance.isOwner, isFalse);
    });

    test('users with no email (anonymous-style) also get ads', () async {
      await AdsController.instance.configureForUser(
        const AppUser(uid: 'no-email-uid'),
      );
      expect(AdsController.instance.adsEnabled.value, isTrue);
      expect(AdsController.instance.isOwner, isFalse);
    });

    test('owner defaults to ads off', () async {
      await AdsController.instance.configureForUser(owner);
      expect(AdsController.instance.adsEnabled.value, isFalse);
      expect(AdsController.instance.isOwner, isTrue);
    });

    test('owner gets their persisted toggle choice back', () async {
      SharedPreferences.setMockInitialValues({'ads.ownerAdsEnabled': true});
      await AdsController.instance.configureForUser(owner);
      expect(AdsController.instance.adsEnabled.value, isTrue);
    });
  });

  group('setOwnerAdsEnabled', () {
    test('owner toggle flips state and persists across sessions', () async {
      await AdsController.instance.configureForUser(owner);
      await AdsController.instance.setOwnerAdsEnabled(true);
      expect(AdsController.instance.adsEnabled.value, isTrue);

      // Simulate the next sign-in reading the same device prefs.
      await AdsController.instance.configureForUser(owner);
      expect(AdsController.instance.adsEnabled.value, isTrue);

      await AdsController.instance.setOwnerAdsEnabled(false);
      await AdsController.instance.configureForUser(owner);
      expect(AdsController.instance.adsEnabled.value, isFalse);
    });

    test('is a no-op for non-owners', () async {
      await AdsController.instance.configureForUser(regular);
      await AdsController.instance.setOwnerAdsEnabled(false);
      expect(AdsController.instance.adsEnabled.value, isTrue);
    });
  });
}
