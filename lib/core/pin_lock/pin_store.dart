import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the app-lock PIN as a salted SHA-256 hash in OS-level secure
/// storage (Android Keystore / iOS Keychain) — never the raw PIN, and never
/// in a plain file like SharedPreferences, since this exists specifically to
/// protect financial data from casual access to an unlocked phone.
class PinStore {
  PinStore._();
  static final instance = PinStore._();

  static const _storage = FlutterSecureStorage();
  static const _hashKey = 'pin_lock_hash';
  static const _saltKey = 'pin_lock_salt';
  static const _enabledKey = 'pin_lock_enabled';

  Future<bool> isSet() async => await _storage.read(key: _hashKey) != null;

  Future<bool> isEnabled() async {
    if (!await isSet()) return false;
    return (await _storage.read(key: _enabledKey)) != 'false';
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled.toString());
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(pin, salt));
    await _storage.write(key: _enabledKey, value: 'true');
  }

  Future<bool> verify(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _hashKey);
    if (salt == null || storedHash == null) return false;
    return _hash(pin, salt) == storedHash;
  }

  Future<void> clear() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _enabledKey);
  }

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }
}
