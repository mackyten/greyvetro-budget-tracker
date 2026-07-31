import 'package:flutter_test/flutter_test.dart';

import 'package:greyvetro_budget_tracker/core/pin_lock/biometric_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No platform implementation is registered in the test environment (there's
  // no real device), which exercises the same code path as a device that
  // doesn't support biometrics — the wrapper must degrade to `false` rather
  // than letting a `MissingPluginException`/`PlatformException` propagate.
  test('isAvailable degrades to false instead of throwing', () async {
    expect(await BiometricAuth.instance.isAvailable(), isFalse);
  });

  test('authenticate degrades to false instead of throwing', () async {
    expect(await BiometricAuth.instance.authenticate(reason: 'test'), isFalse);
  });
}
