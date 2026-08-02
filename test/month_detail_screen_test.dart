import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:greyvetro_budget_tracker/core/design_tokens.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/data/budget_repository.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/models/account.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/models/monthly_entry.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/ui/month_detail_screen.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/ui/voice_input_button.dart';

class _RecordingRepository implements BudgetRepository {
  final List<MonthlyEntry> saved = [];

  @override
  Stream<List<Account>> watchAccounts() => Stream.value(const []);

  @override
  Future<void> addAccount(Account account) async {}

  @override
  Future<void> updateAccount(Account account) async {}

  @override
  Future<void> setAccountActive(String accountId, bool active) async {}

  @override
  Stream<List<MonthlyEntry>> watchMonthlyEntries() => Stream.value(const []);

  @override
  Future<MonthlyEntry?> getMonthlyEntry(String entryId) async => null;

  @override
  Future<void> saveMonthlyEntry(MonthlyEntry entry) async {
    saved.add(entry);
  }

  @override
  Future<void> deleteAllData() async {}
}

final _account = Account(
  id: 'cash',
  name: 'Cash Wallet',
  section: AccountSection.asset,
  order: 0,
);

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, extensions: const [AppPalette.light]),
    home: Scaffold(body: child),
  );
}

void main() {
  const homeWidgetChannel = MethodChannel('home_widget');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // `_save()` calls updateHomeWidget(), which hits the real `home_widget`
    // platform channel. With no handler registered, flutter_test buffers the
    // call indefinitely instead of failing it, which hangs pumpAndSettle.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
  });

  testWidgets('typing a balance groups it with thousands separators', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(_wrap(MonthDetailSheet(
      repository: repository,
      entry: MonthlyEntry(month: DateTime(2026, 1), balances: const {}),
      accounts: [_account],
      previous: null,
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '1234567.89');
    await tester.pump();

    expect(find.text('1,234,567.89'), findsOneWidget);
  });

  testWidgets('anomaly guard blocks save until confirmed', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(_wrap(MonthDetailSheet(
      repository: repository,
      entry: MonthlyEntry(month: DateTime(2026, 2), balances: const {}),
      accounts: [_account],
      previous: MonthlyEntry(month: DateTime(2026, 1), balances: const {'cash': 10000}),
    )));
    await tester.pumpAndSettle();

    // 100,000 vs previous 10,000 is a >60% swing — should trip the guard.
    await tester.enterText(find.byType(TextField).first, '100000');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Large balance change'), findsOneWidget);
    expect(repository.saved, isEmpty);

    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.balances['cash'], 100000);
  });

  testWidgets('toggling lock saves immediately and makes fields read-only', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(_wrap(MonthDetailSheet(
      repository: repository,
      entry: MonthlyEntry(month: DateTime(2026, 3), balances: const {'cash': 500}),
      accounts: [_account],
      previous: null,
    )));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_open), findsOneWidget);

    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.locked, isTrue);

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.readOnly, isTrue);

    final voiceButton = tester.widget<VoiceInputButton>(find.byType(VoiceInputButton));
    expect(voiceButton.enabled, isFalse);
  });
}
