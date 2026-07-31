import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/vault_item.dart';

/// Persists Secure Vault items as a single JSON blob in
/// `flutter_secure_storage` — deliberately never touches `BudgetRepository`
/// or `cloud_firestore`, mirroring how `lib/core/pin_lock/` is its own
/// self-contained island. This is the *only* file in the vault module that
/// touches storage.
class VaultStore {
  VaultStore._();
  static final instance = VaultStore._();

  static const _storage = FlutterSecureStorage();
  static const _itemsKey = 'vault_items_v1';

  final ValueNotifier<List<VaultItem>> items = ValueNotifier<List<VaultItem>>(const []);

  Future<List<VaultItem>> loadAll() async {
    final raw = await _storage.read(key: _itemsKey);
    final list = raw == null
        ? <VaultItem>[]
        : (jsonDecode(raw) as List)
            .map((e) => VaultItem.fromJson(e as Map<String, dynamic>))
            .toList();
    items.value = list;
    return list;
  }

  Future<void> upsert(VaultItem item) async {
    final list = List<VaultItem>.from(items.value);
    final index = list.indexWhere((e) => e.id == item.id);
    if (index == -1) {
      list.add(item);
    } else {
      list[index] = item;
    }
    items.value = list;
    await _persist(list);
  }

  Future<void> delete(String id) async {
    final list = items.value.where((e) => e.id != id).toList();
    items.value = list;
    await _persist(list);
  }

  Future<void> _persist(List<VaultItem> list) async {
    await _storage.write(
      key: _itemsKey,
      value: jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  /// Same `Random.secure()` + `base64Url.encode` pattern `PinStore` uses for
  /// its salt, inlined here rather than pulling in a `uuid` package.
  String generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }
}
