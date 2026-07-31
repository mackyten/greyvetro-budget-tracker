import 'package:local_auth/local_auth.dart';

/// Thin wrapper around `local_auth` — Android-only per project scope (there's
/// no `ios/` directory in this app). Isolated behind this class so the rest
/// of the PIN-lock/vault code doesn't depend on the plugin API directly.
class BiometricAuth {
  BiometricAuth._();
  static final instance = BiometricAuth._();

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}
