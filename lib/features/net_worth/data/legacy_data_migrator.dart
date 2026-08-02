import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time move of pre-auth data into the signed-in user's namespace.
///
/// Before Firebase Auth was wired in (see TASKS.md TASK-001),
/// [FirestoreBudgetRepository] read/wrote top-level `accounts` and
/// `monthlyEntries` collections with no owner. This copies whatever is there
/// into `users/{uid}/...` the first time that user signs in, so existing
/// data isn't orphaned by the switch to per-user paths.
///
/// Safe to call on every launch: no-ops once `users/{uid}/accounts` is
/// non-empty. `firestore.rules` only grants read access to the legacy
/// top-level collections while this migration is still relevant — see the
/// TEMPORARY block there.
Future<void> migrateLegacyDataIfNeeded(FirebaseFirestore db, String uid) async {
  final userDoc = db.collection('users').doc(uid);

  final alreadyMigrated = await userDoc.collection('accounts').limit(1).get();
  if (alreadyMigrated.docs.isNotEmpty) return;

  final legacyAccounts = await db.collection('accounts').get();
  if (legacyAccounts.docs.isEmpty) return;

  final legacyEntries = await db.collection('monthlyEntries').get();

  final batch = db.batch();
  for (final doc in legacyAccounts.docs) {
    batch.set(userDoc.collection('accounts').doc(doc.id), doc.data());
  }
  for (final doc in legacyEntries.docs) {
    batch.set(userDoc.collection('monthlyEntries').doc(doc.id), doc.data());
  }
  await batch.commit();
}
