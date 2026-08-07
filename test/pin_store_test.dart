import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetro_ledger/core/pin_lock/pin_store.dart';

/// Same in-memory fake as `widget_test.dart` / `vault_entry_test.dart`, so
/// PinStore hits a map instead of an unmocked platform channel.
class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return _values[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return _values.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    return Map.of(_values);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = PinStore.instance;
  // Raw handle on the same storage, for planting legacy-format values and
  // inspecting what the store persisted.
  const rawStorage = FlutterSecureStorage();

  setUp(() async {
    FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
    store.now = DateTime.now;
    await store.clear();
  });

  test('setPin stores a versioned stretched hash, not the raw PIN', () async {
    await store.setPin('1234');
    final stored = await rawStorage.read(key: 'pin_lock_hash');
    expect(stored, startsWith('v2:'));
    expect(stored, isNot(contains('1234')));
    expect(await store.verify('1234'), isTrue);
    expect(await store.verify('4321'), isFalse);
  });

  test(
    'legacy single-round hash still verifies, then upgrades to v2',
    () async {
      // Plant exactly what the pre-hardening PinStore wrote: bare
      // sha256("salt:pin") hex with no version prefix.
      const salt = 'legacy-salt';
      await rawStorage.write(key: 'pin_lock_salt', value: salt);
      await rawStorage.write(
        key: 'pin_lock_hash',
        value: sha256.convert(utf8.encode('$salt:1234')).toString(),
      );
      await rawStorage.write(key: 'pin_lock_enabled', value: 'true');

      // A wrong guess against the legacy format must not upgrade or unlock.
      expect(await store.verify('9999'), isFalse);
      expect(
        await rawStorage.read(key: 'pin_lock_hash'),
        isNot(startsWith('v2:')),
      );

      // The first successful verify migrates: v2 prefix, fresh salt.
      expect(await store.verify('1234'), isTrue);
      expect(await rawStorage.read(key: 'pin_lock_hash'), startsWith('v2:'));
      expect(await rawStorage.read(key: 'pin_lock_salt'), isNot(salt));

      // And the migrated hash keeps working.
      expect(await store.verify('1234'), isTrue);
      expect(await store.verify('9999'), isFalse);
    },
  );

  test('lockout starts after free attempts, escalates, and caps', () async {
    await store.setPin('1234');
    var fakeNow = DateTime(2026, 1, 1);
    store.now = () => fakeNow;

    // First four failures are free.
    for (var i = 0; i < PinStore.maxFreeAttempts - 1; i++) {
      expect(await store.verify('0000'), isFalse);
      expect(await store.lockoutRemaining(), isNull);
    }

    // Failure #5 locks for 30s; the correct PIN is refused while locked.
    expect(await store.verify('0000'), isFalse);
    expect((await store.lockoutRemaining())!.inSeconds, 30);
    expect(await store.verify('1234'), isFalse);
    expect(
      (await store.lockoutRemaining())!.inSeconds,
      30,
      reason: 'a guess during lockout must not restart or extend it',
    );

    // Each further failure doubles: 60, 120, 240, then capped at 300.
    for (final expected in [60, 120, 240, 300, 300]) {
      fakeNow = fakeNow.add(const Duration(minutes: 10));
      expect(await store.lockoutRemaining(), isNull);
      expect(await store.verify('0000'), isFalse);
      expect((await store.lockoutRemaining())!.inSeconds, expected);
    }
  });

  test('successful verify resets the failure counter', () async {
    await store.setPin('1234');
    var fakeNow = DateTime(2026, 1, 1);
    store.now = () => fakeNow;

    for (var i = 0; i < PinStore.maxFreeAttempts; i++) {
      await store.verify('0000');
    }
    expect(await store.lockoutRemaining(), isNotNull);

    fakeNow = fakeNow.add(const Duration(minutes: 10));
    expect(await store.verify('1234'), isTrue);
    expect(await store.lockoutRemaining(), isNull);

    // Counter went back to zero: the next failure is free again instead of
    // continuing the doubling ladder.
    expect(await store.verify('0000'), isFalse);
    expect(await store.lockoutRemaining(), isNull);
  });

  test('clear wipes throttle state along with the PIN', () async {
    await store.setPin('1234');
    var fakeNow = DateTime(2026, 1, 1);
    store.now = () => fakeNow;
    for (var i = 0; i < PinStore.maxFreeAttempts; i++) {
      await store.verify('0000');
    }
    expect(await store.lockoutRemaining(), isNotNull);

    await store.clear();
    expect(await store.lockoutRemaining(), isNull);
    expect(await store.isSet(), isFalse);
  });
}
