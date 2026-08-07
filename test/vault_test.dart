import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetro_ledger/features/vault/data/vault_store.dart';
import 'package:vetro_ledger/features/vault/models/vault_item.dart';

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
  Future<String?> read({required String key, required Map<String, String> options}) async {
    return _values[key];
  }

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async {
    return _values.containsKey(key);
  }

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async {
    return Map.of(_values);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }
}

VaultItem _note({required String id, required String title}) {
  final now = DateTime(2026, 1, 1);
  return VaultItem(id: id, kind: VaultItemKind.note, title: title, body: 'body', createdAt: now, updatedAt: now);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
    VaultStore.instance.items.value = const [];
  });

  test('upsert then loadAll round-trips a vault item', () async {
    await VaultStore.instance.upsert(_note(id: 'a', title: 'Wifi'));

    final loaded = await VaultStore.instance.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Wifi');
    expect(VaultStore.instance.items.value, hasLength(1));
  });

  test('upsert with an existing id replaces rather than duplicates', () async {
    await VaultStore.instance.upsert(_note(id: 'a', title: 'Wifi'));
    await VaultStore.instance.upsert(_note(id: 'a', title: 'Wifi (updated)'));

    final loaded = await VaultStore.instance.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Wifi (updated)');
  });

  test('delete removes the item and persists the removal', () async {
    await VaultStore.instance.upsert(_note(id: 'a', title: 'Wifi'));
    await VaultStore.instance.upsert(_note(id: 'b', title: 'Router login'));

    await VaultStore.instance.delete('a');

    expect(VaultStore.instance.items.value.map((e) => e.id), ['b']);
    final reloaded = await VaultStore.instance.loadAll();
    expect(reloaded.map((e) => e.id), ['b']);
  });

  test('generateId produces distinct ids', () {
    final ids = {for (var i = 0; i < 20; i++) VaultStore.instance.generateId()};
    expect(ids, hasLength(20));
  });
}
