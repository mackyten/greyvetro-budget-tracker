import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../models/monthly_entry.dart';
import 'budget_repository.dart';

/// Firestore-backed [BudgetRepository].
///
/// Collections (top-level, single-user — see README for the planned
/// per-user scoping once greyvetro-auth-hub is wired in):
///   accounts/{accountId}       -> Account.toMap()
///   monthlyEntries/{YYYY-MM}   -> MonthlyEntry.toMap()
class FirestoreBudgetRepository implements BudgetRepository {
  FirestoreBudgetRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _accounts =>
      _db.collection('accounts');
  CollectionReference<Map<String, dynamic>> get _monthlyEntries =>
      _db.collection('monthlyEntries');

  @override
  Stream<List<Account>> watchAccounts() {
    return _accounts.orderBy('order').snapshots().map(
          (snap) => snap.docs
              .map((doc) => Account.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> addAccount(Account account) {
    return _accounts.doc(account.id).set(account.toMap());
  }

  @override
  Future<void> updateAccount(Account account) {
    return _accounts.doc(account.id).update(account.toMap());
  }

  @override
  Future<void> setAccountActive(String accountId, bool active) {
    return _accounts.doc(accountId).update({'active': active});
  }

  @override
  Stream<List<MonthlyEntry>> watchMonthlyEntries() {
    return _monthlyEntries.orderBy(FieldPath.documentId).snapshots().map(
          (snap) => snap.docs
              .map((doc) => MonthlyEntry.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<MonthlyEntry?> getMonthlyEntry(String entryId) async {
    final doc = await _monthlyEntries.doc(entryId).get();
    if (!doc.exists) return null;
    return MonthlyEntry.fromMap(doc.id, doc.data()!);
  }

  @override
  Future<void> saveMonthlyEntry(MonthlyEntry entry) {
    return _monthlyEntries.doc(entry.id).set(entry.toMap());
  }
}
