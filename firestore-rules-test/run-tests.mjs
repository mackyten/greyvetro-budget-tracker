// Emulator tests for ../firestore.rules (security audit tier 2).
//
// One case per real write path in FirestoreBudgetRepository — so a rules
// change that would lock out the app fails loudly here — plus the attack
// cases the shape validation exists to block (extra keys, wrong types,
// oversized strings, off-schema collections, cross-user access).
//
// Run from this directory with `npm test`; it wraps this script in
// `firebase emulators:exec --only firestore`, which exports
// FIRESTORE_EMULATOR_HOST so initializeTestEnvironment finds the emulator.
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'greyvetro-rules-test',
  firestore: {
    rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
  },
});

// Mirrors Account.toMap(): reservedKind is always present, null for assets.
const validAccount = {
  name: 'BPI Savings',
  section: 'asset',
  reservedKind: null,
  order: 0,
  active: true,
  cashCounter: false,
};

// Mirrors MonthlyEntry.toMap(): note always present, possibly null.
const validEntry = {
  balances: { 'bpi-savings': 1234.56 },
  note: null,
  locked: false,
};

let failed = 0;
async function expectAllow(label, promise) {
  try {
    await assertSucceeds(promise);
    console.log(`  PASS (allowed): ${label}`);
  } catch (e) {
    failed++;
    console.error(`  FAIL (should be ALLOWED): ${label}\n    ${e.message}`);
  }
}
async function expectDeny(label, promise) {
  try {
    await assertFails(promise);
    console.log(`  PASS (denied):  ${label}`);
  } catch (e) {
    failed++;
    console.error(`  FAIL (should be DENIED): ${label}\n    ${e.message}`);
  }
}

// Seed docs as the backend (rules bypassed), the way existing prod data
// already sits in Firestore before these stricter rules deploy.
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/alice/accounts/existing'), validAccount);
  // Legacy shape: written before `active`/`cashCounter` existed
  // (Account.fromMap defaults both) — must remain partially updatable.
  await setDoc(doc(db, 'users/alice/accounts/legacy'), {
    name: 'Old Wallet',
    section: 'asset',
    reservedKind: null,
    order: 1,
  });
  await setDoc(doc(db, 'users/alice/monthlyEntries/2026-07'), validEntry);
});

const alice = env.authenticatedContext('alice').firestore();
const mallory = env.authenticatedContext('mallory').firestore();
const anon = env.unauthenticatedContext().firestore();

console.log('Repo write paths (must all stay allowed):');
// addAccount → set() on a new doc
await expectAllow('addAccount: create full Account.toMap()',
  setDoc(doc(alice, 'users/alice/accounts/new-acct'), validAccount));
// updateAccount → update() with the full map
await expectAllow('updateAccount: full-map update',
  updateDoc(doc(alice, 'users/alice/accounts/existing'), { ...validAccount, name: 'BPI Renamed' }));
// setAccountActive → update() of just {active}
await expectAllow('setAccountActive: partial update on current-shape doc',
  updateDoc(doc(alice, 'users/alice/accounts/existing'), { active: false }));
await expectAllow('setAccountActive: partial update on legacy doc (no active/cashCounter fields)',
  updateDoc(doc(alice, 'users/alice/accounts/legacy'), { active: false }));
// saveMonthlyEntry → set(), both first save (create) and re-save (overwrite)
await expectAllow('saveMonthlyEntry: create new month',
  setDoc(doc(alice, 'users/alice/monthlyEntries/2026-08'), validEntry));
await expectAllow('saveMonthlyEntry: overwrite existing month',
  setDoc(doc(alice, 'users/alice/monthlyEntries/2026-07'), { ...validEntry, locked: true }));
await expectAllow('saveMonthlyEntry: entry with a real note',
  setDoc(doc(alice, 'users/alice/monthlyEntries/2026-06'), { ...validEntry, note: 'payday landed late' }));
// deleteAllData → batch deletes of both collections, then the parent doc
await expectAllow('deleteAllData: delete account doc',
  deleteDoc(doc(alice, 'users/alice/accounts/new-acct')));
await expectAllow('deleteAllData: delete monthly entry doc',
  deleteDoc(doc(alice, 'users/alice/monthlyEntries/2026-08')));
await expectAllow('deleteAllData: delete parent users/{uid} doc',
  deleteDoc(doc(alice, 'users/alice')));
// reads
await expectAllow('read own account doc',
  getDoc(doc(alice, 'users/alice/accounts/existing')));

console.log('Shape violations (must all be denied):');
await expectDeny('account create with an extra key',
  setDoc(doc(alice, 'users/alice/accounts/x1'), { ...validAccount, injected: 'blob' }));
await expectDeny('account create missing required keys',
  setDoc(doc(alice, 'users/alice/accounts/x2'), { name: 'Sparse', section: 'asset' }));
await expectDeny('account create with name over 200 chars',
  setDoc(doc(alice, 'users/alice/accounts/x3'), { ...validAccount, name: 'x'.repeat(201) }));
await expectDeny('account create with wrong-typed order',
  setDoc(doc(alice, 'users/alice/accounts/x4'), { ...validAccount, order: 'first' }));
await expectDeny('account create with unknown section value',
  setDoc(doc(alice, 'users/alice/accounts/x5'), { ...validAccount, section: 'crypto' }));
await expectDeny('account update sneaking in an extra key',
  updateDoc(doc(alice, 'users/alice/accounts/existing'), { injected: 'blob' }));
await expectDeny('entry create with malformed doc id',
  setDoc(doc(alice, 'users/alice/monthlyEntries/not-a-month'), validEntry));
await expectDeny('entry create with an extra key',
  setDoc(doc(alice, 'users/alice/monthlyEntries/2026-05'), { ...validEntry, injected: 'blob' }));
await expectDeny('entry create with non-map balances',
  setDoc(doc(alice, 'users/alice/monthlyEntries/2026-04'), { ...validEntry, balances: 'lots' }));
await expectDeny('entry create with note over 2000 chars',
  setDoc(doc(alice, 'users/alice/monthlyEntries/2026-03'), { ...validEntry, note: 'x'.repeat(2001) }));
await expectDeny('entry create with non-bool locked',
  setDoc(doc(alice, 'users/alice/monthlyEntries/2026-02'), { ...validEntry, locked: 'yes' }));

console.log('Off-schema and cross-user access (must all be denied):');
await expectDeny('create fields on parent users/{uid} doc',
  setDoc(doc(alice, 'users/alice'), { hoard: 'anything' }));
await expectDeny('write to an unknown subcollection under own uid',
  setDoc(doc(alice, 'users/alice/scratch/blob1'), { data: 'x'.repeat(1000) }));
await expectDeny('write to a top-level collection',
  setDoc(doc(alice, 'public/spam'), { hello: 'world' }));
await expectDeny("mallory reads alice's account",
  getDoc(doc(mallory, 'users/alice/accounts/existing')));
await expectDeny("mallory writes alice's account",
  setDoc(doc(mallory, 'users/alice/accounts/evil'), validAccount));
await expectDeny("mallory deletes alice's entry",
  deleteDoc(doc(mallory, 'users/alice/monthlyEntries/2026-07')));
await expectDeny('unauthenticated read',
  getDoc(doc(anon, 'users/alice/accounts/existing')));

await env.cleanup();

if (failed > 0) {
  console.error(`\n${failed} rules test(s) FAILED`);
  process.exit(1);
}
console.log('\nAll rules tests passed.');
