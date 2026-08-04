import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the app-lock PIN as a salted, key-stretched SHA-256 hash in
/// OS-level secure storage (Android Keystore / iOS Keychain) — never the raw
/// PIN, and never in a plain file like SharedPreferences, since this exists
/// specifically to protect financial data from casual access to an unlocked
/// phone.
///
/// Two hardening layers (security audit tier 3), both living here rather
/// than in the UI so they hold for every verify caller and survive app
/// restarts:
///
/// 1. **Key stretching.** A 4-digit PIN has only 10,000 possibilities, so a
///    single fast SHA-256 is trivially brute-forced offline if the Keystore
///    entries are ever extracted (e.g. rooted device). The current scheme
///    (`v2:` prefix) chains [_hashIterations] rounds of SHA-256 over
///    `salt:pin` — a PBKDF2-style work factor using the existing `crypto`
///    package, no new dependency. Hashes written before this scheme are bare
///    single-round digests; [verify] still accepts them and transparently
///    re-hashes to v2 (with a fresh salt) on the first successful unlock, so
///    no existing user is ever locked out by the upgrade.
///
/// 2. **Attempt throttling.** Online guessing gets [maxFreeAttempts] free
///    tries, then an escalating lockout: [baseLockout], doubling on each
///    further failure, capped at [maxLockout]. State is persisted in the
///    same secure storage so relaunching the app doesn't reset the clock.
///    Biometric unlock is deliberately unaffected — it doesn't go through
///    [verify].
class PinStore {
  PinStore._();
  static final instance = PinStore._();

  static const _storage = FlutterSecureStorage();
  static const _hashKey = 'pin_lock_hash';
  static const _saltKey = 'pin_lock_salt';
  static const _enabledKey = 'pin_lock_enabled';
  static const _biometricEnabledKey = 'pin_lock_biometric_enabled';
  static const _failedAttemptsKey = 'pin_lock_failed_attempts';
  static const _lockoutUntilKey = 'pin_lock_lockout_until';

  /// `v2:` marks the iterated scheme; a stored hash without it is legacy
  /// single-round. The version prefix (rather than sniffing hash length) is
  /// what lets [verify] pick the right scheme and future schemes bump to v3.
  static const _hashVersionPrefix = 'v2:';

  /// ~100k rounds turns a full 10,000-PIN offline sweep from microseconds
  /// into minutes-per-guess territory on commodity hardware while staying
  /// well under a perceptible pause on-device (32-byte SHA-256 rounds are
  /// cheap; the chain measures in tens of milliseconds).
  static const _hashIterations = 100000;

  /// Failures allowed before the first lockout kicks in — generous enough
  /// that a fumbled real PIN never hits it.
  static const maxFreeAttempts = 5;

  /// First lockout length; doubles per subsequent failure up to [maxLockout].
  static const baseLockout = Duration(seconds: 30);
  static const maxLockout = Duration(minutes: 5);

  /// Injectable time source so lockout tests can step a fake clock instead
  /// of sleeping through real 30s+ windows. Production never touches this.
  DateTime Function() now = DateTime.now;

  Future<bool> isSet() async => await _storage.read(key: _hashKey) != null;

  Future<bool> isEnabled() async {
    if (!await isSet()) return false;
    return (await _storage.read(key: _enabledKey)) != 'false';
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    return (await _storage.read(key: _biometricEnabledKey)) == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(
      key: _hashKey,
      value: _hashVersionPrefix + _hashV2(pin, salt),
    );
    await _storage.write(key: _enabledKey, value: 'true');
    await _resetThrottle();
  }

  /// How long until PIN entry is allowed again, or null when not locked out.
  /// UIs should poll this to drive their countdown and disable the keypad.
  Future<Duration?> lockoutRemaining() async {
    final raw = await _storage.read(key: _lockoutUntilKey);
    final until = raw == null ? null : int.tryParse(raw);
    if (until == null) return null;
    final remaining = until - now().millisecondsSinceEpoch;
    return remaining > 0 ? Duration(milliseconds: remaining) : null;
  }

  /// Checks [pin], enforcing the lockout and recording failures. While
  /// locked out this returns false without even comparing — a correct guess
  /// during lockout neither unlocks nor resets anything, so the lockout
  /// can't be probed.
  Future<bool> verify(String pin) async {
    if (await lockoutRemaining() != null) return false;

    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _hashKey);
    if (salt == null || storedHash == null) return false;

    final legacy = !storedHash.startsWith(_hashVersionPrefix);
    final ok = legacy
        ? _hashV1(pin, salt) == storedHash
        : _hashVersionPrefix + _hashV2(pin, salt) == storedHash;

    if (!ok) {
      await _recordFailure();
      return false;
    }

    await _resetThrottle();
    if (legacy) {
      // The PIN is only in hand during a successful verify, so this is the
      // one moment a stored legacy hash can be upgraded. Fresh salt on
      // purpose: the old salt already leaked alongside the weak hash in any
      // extraction scenario the stretching defends against.
      final newSalt = _generateSalt();
      await _storage.write(key: _saltKey, value: newSalt);
      await _storage.write(
        key: _hashKey,
        value: _hashVersionPrefix + _hashV2(pin, newSalt),
      );
    }
    return true;
  }

  Future<void> clear() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _biometricEnabledKey);
    await _resetThrottle();
  }

  Future<void> _resetThrottle() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockoutUntilKey);
  }

  Future<void> _recordFailure() async {
    final raw = await _storage.read(key: _failedAttemptsKey);
    final attempts = (raw == null ? 0 : int.tryParse(raw) ?? 0) + 1;
    await _storage.write(key: _failedAttemptsKey, value: attempts.toString());
    if (attempts < maxFreeAttempts) return;

    // Failure #maxFreeAttempts locks for baseLockout, each one after that
    // doubles it. The shift count is clamped because the cap is reached
    // after 4 doublings anyway and unbounded 1 << n would overflow.
    final doublings = min(attempts - maxFreeAttempts, 10);
    var lockout = baseLockout * (1 << doublings);
    if (lockout > maxLockout) lockout = maxLockout;
    await _storage.write(
      key: _lockoutUntilKey,
      value: (now().millisecondsSinceEpoch + lockout.inMilliseconds).toString(),
    );
  }

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Legacy scheme: single salted SHA-256 — kept only so hashes stored
  /// before v2 keep verifying until their one-time upgrade in [verify].
  String _hashV1(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  /// Current scheme: [_hashIterations] chained SHA-256 rounds over
  /// `salt:pin`. Runs synchronously on purpose — the chain is tens of
  /// milliseconds of 32-byte hashing behind a full-screen PIN UI, which
  /// isn't worth an isolate round-trip or a Flutter dependency in this
  /// otherwise pure-Dart store.
  String _hashV2(String pin, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$pin'));
    for (var i = 1; i < _hashIterations; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return digest.toString();
  }
}
