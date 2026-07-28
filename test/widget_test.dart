import 'package:flutter_test/flutter_test.dart';

import 'package:greyvetro_budget_tracker/features/net_worth/data/budget_repository.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/models/account.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/models/monthly_entry.dart';
import 'package:greyvetro_budget_tracker/main.dart';

class _FakeBudgetRepository implements BudgetRepository {
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
  Future<void> saveMonthlyEntry(MonthlyEntry entry) async {}
}

void main() {
  testWidgets('Month list screen renders with no data', (tester) async {
    await tester.pumpWidget(BudgetTrackerApp(repository: _FakeBudgetRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Net Worth / Liquidity Tracker'), findsOneWidget);
    expect(find.text('No months tracked yet. Tap + to add one.'), findsOneWidget);
  });
}
