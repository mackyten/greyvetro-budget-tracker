import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../models/monthly_entry.dart';
import 'budget_repository.dart';

/// Firestore-backed [BudgetRepository], scoped to the signed-in user.
///
/// Collections (nested under the owning user, per Firestore rules keyed on
/// `request.auth.uid` — see firestore.rules):
///   users/{uid}/accounts/{accountId}       -> Account.toMap()
///   users/{uid}/monthlyEntries/{YYYY-MM}   -> MonthlyEntry.toMap()
class FirestoreBudgetRepository implements BudgetRepository {
  FirestoreBudgetRepository({required String uid, FirebaseFirestore? firestore})
      : _uid = uid,
        _db = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(_uid);
  CollectionReference<Map<String, dynamic>> get _accounts =>
      _userDoc.collection('accounts');
  CollectionReference<Map<String, dynamic>> get _monthlyEntries =>
      _userDoc.collection('monthlyEntries');

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
