import '../models/account.dart';
import '../models/monthly_entry.dart';

/// Storage boundary for the Net Worth / Liquidity Tracker feature. Kept
/// separate from [FirestoreBudgetRepository] so the UI/business logic never
/// depends on Firestore types directly.
abstract class BudgetRepository {
  Stream<List<Account>> watchAccounts();

  Future<void> addAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> setAccountActive(String accountId, bool active);

  Stream<List<MonthlyEntry>> watchMonthlyEntries();
  Future<MonthlyEntry?> getMonthlyEntry(String entryId);
  Future<void> saveMonthlyEntry(MonthlyEntry entry);
}
