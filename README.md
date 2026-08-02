# Greyvetro Budget Tracker

Android Flutter app that replaces the "Net Worth / Liquidity Tracker" sheet
from the personal Numbers budget spreadsheet. Backed by Firebase (Firestore).

## Architecture

```
lib/
├── core/
│   └── format.dart                      # currency/date/percent formatters
├── features/net_worth/
│   ├── models/
│   │   ├── account.dart                 # a tracked line item (asset or reserved/liability)
│   │   ├── monthly_entry.dart           # one month's balances + note
│   │   └── month_summary.dart           # computed totals/savings/% change (never persisted)
│   ├── data/
│   │   ├── budget_repository.dart       # storage-agnostic interface
│   │   └── firestore_budget_repository.dart
│   └── ui/
│       ├── month_list_screen.dart       # home: month list + net savings trend
│       ├── month_detail_screen.dart     # edit a month's balances, live-computed totals
│       └── manage_accounts_screen.dart  # add/archive accounts
├── firebase_options.dart                # PLACEHOLDER — see Setup below
└── main.dart
```

### Data model (Firestore)

Everything lives under the signed-in user, `users/{uid}/...` (`uid` is a
Firebase Auth uid — see Authentication below):

- `users/{uid}/accounts/{accountId}` — one doc per tracked line item: `name`,
  `section` (`asset` | `reservedLiability`), `reservedKind` (`reserved` |
  `creditCard`, only for the reserved/liability section), `order`, `active`.
- `users/{uid}/monthlyEntries/{YYYY-MM}` — one doc per month: `balances` (map
  of `accountId` → number, sparse — a missing key means blank, same as an
  empty cell in the original sheet) and an optional `note`.

Everything else (Total Assets, Total Reserved & Liabilities, Net Savings,
month-over-month % change, current month saved) is computed client-side by
`MonthSummary.compute` from `balances` + the account list, so it can never
drift out of sync the way a spreadsheet formula copy-paste can.

`assets/seed/net_worth_seed.json` is the actual historical data extracted
from `Budget Tracker 2.numbers` (Apr 2025 – Jul 2026, 23 accounts). It was
one-time imported into the original owner's account; the app no longer
auto-imports it (that auto-import used to run for every new sign-in, not
just the original owner — every account starts empty now).

## Setup

1. **Firebase project.** Log into the Google account that should own this
   project (`firebase login --reauth` if the CLI is signed into the wrong
   account), then either create a new project or pick an existing one.
2. **FlutterFire configure** (generates the real `lib/firebase_options.dart`,
   replacing the placeholder committed here):
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
3. **Enable Google Sign-In** in the Firebase console (Authentication →
   Sign-in method → Google), and register your debug/release keystore's
   SHA-1 fingerprint under the Android app's settings (Project settings →
   your Android app → Add fingerprint). Get it with:
   ```
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   Without this, Google Sign-In will fail on Android with an
   `ApiException: 10` (`DEVELOPER_ERROR`).
4. **Deploy Firestore rules/indexes**:
   ```
   firebase deploy --only firestore:rules,firestore:indexes
   ```
   `firestore.rules` scopes all reads/writes to `users/{uid}/...` via
   `request.auth.uid` — see the comment in that file, and Authentication
   below.
5. **Run**:
   ```
   flutter run -d android
   ```

## Authentication

The app requires sign-in (Google, via Firebase Auth) before showing any
data — see `lib/core/auth/`. This is separate from, and happens before, the
local PIN/biometric lock: sign-in gates the Firestore backend, the PIN gates
the device.

`AuthService` (`lib/core/auth/auth_service.dart`) is a small provider-agnostic
interface; `FirebaseGoogleAuthService` is the only implementation today. Data
written before auth existed (top-level `accounts`/`monthlyEntries`
collections, pre-TASK-001) was one-time migrated into the owning user's
`users/{uid}/...` namespace and the legacy top-level collections have since
been deleted, along with the temporary rule and migrator code that supported
that migration — `firestore.rules` now only ever grants access to
`users/{uid}/...`, scoped to that uid.

### Planned: greyvetro-auth-hub integration

This app will eventually authenticate against `greyvetro-auth-hub`
(Keycloak) instead of signing in with Google directly. That requires a
backend step to exchange a verified Keycloak token for a Firebase custom
auth token (Firestore has no native Keycloak/OIDC verification), then
`FirebaseAuth.instance.signInWithCustomToken`. Because that still produces a
normal Firebase Auth session, `AppUser.uid`, `firestore.rules`, and
`FirestoreBudgetRepository`'s `users/{uid}/...` paths all stay exactly as
they are — the swap is contained to adding a new `AuthService`
implementation and pointing `main.dart` at it. Not started yet — tracked in
`TASKS.md`.

## Known issues / tech debt

- `lib/firebase_options.dart` is a placeholder; run `flutterfire configure`
  before shipping to a real device/project.
