import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetro_ledger/core/design_tokens.dart';
import 'package:vetro_ledger/core/pin_lock/pin_store.dart';
import 'package:vetro_ledger/features/vault/ui/vault_entry.dart';

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

Widget _wrap() {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, extensions: const [AppPalette.light]),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => openVault(context),
            child: const Text('Open Vault'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
    await PinStore.instance.clear();
  });

  testWidgets('vault is inaccessible without a PIN', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('Open Vault'));
    await tester.pumpAndSettle();

    expect(find.text('Set up a PIN to use the Vault'), findsOneWidget);
    expect(find.text('Secure Vault'), findsNothing);
  });

  testWidgets('correct PIN opens the vault home', (tester) async {
    await PinStore.instance.setPin('1234');
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('Open Vault'));
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN to open Vault'), findsOneWidget);

    await _enterPin(tester, '1234');
    await tester.pumpAndSettle();

    expect(find.text('Secure Vault'), findsOneWidget);
  });

  testWidgets('the "Set up PIN" CTA from inside the vault entry proceeds into the vault',
      (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('Open Vault'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set up PIN'));
    await tester.pumpAndSettle();

    // CreatePinScreen: enter once, then confirm.
    await _enterPin(tester, '1234');
    await tester.pumpAndSettle();
    await _enterPin(tester, '1234');
    await tester.pumpAndSettle();

    expect(find.text('Secure Vault'), findsOneWidget);
    expect(await PinStore.instance.isSet(), isTrue);
  });
}
