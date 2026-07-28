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
│   │   ├── firestore_budget_repository.dart
│   │   └── seed_importer.dart           # one-time import of the original spreadsheet history
│   └── ui/
│       ├── month_list_screen.dart       # home: month list + net savings trend
│       ├── month_detail_screen.dart     # edit a month's balances, live-computed totals
│       └── manage_accounts_screen.dart  # add/archive accounts
├── firebase_options.dart                # PLACEHOLDER — see Setup below
└── main.dart
```

### Data model (Firestore)

- `accounts/{accountId}` — one doc per tracked line item: `name`, `section`
  (`asset` | `reservedLiability`), `reservedKind` (`reserved` | `creditCard`,
  only for the reserved/liability section), `order`, `active`.
- `monthlyEntries/{YYYY-MM}` — one doc per month: `balances` (map of
  `accountId` → number, sparse — a missing key means blank, same as an empty
  cell in the original sheet) and an optional `note`.

Everything else (Total Assets, Total Reserved & Liabilities, Net Savings,
month-over-month % change, current month saved) is computed client-side by
`MonthSummary.compute` from `balances` + the account list, so it can never
drift out of sync the way a spreadsheet formula copy-paste can.

`assets/seed/net_worth_seed.json` is the actual historical data extracted
from `Budget Tracker 2.numbers` (Apr 2025 – Jul 2026, 23 accounts). The app
imports it automatically on first launch if the `accounts` collection is
still empty — it never overwrites existing data.

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
3. **Deploy Firestore rules/indexes**:
   ```
   firebase deploy --only firestore:rules,firestore:indexes
   ```
   `firestore.rules` is a *temporary* time-boxed open rule (no `request.auth`
   exists yet) — see the comment in that file. It must be replaced with real
   per-user rules once greyvetro-auth-hub is wired in.
4. **Run**:
   ```
   flutter run -d android
   ```

## Planned: greyvetro-auth-hub integration

This app will eventually authenticate against `greyvetro-auth-hub`
(Keycloak) instead of being a single-user app with open Firestore rules.
That requires a backend step to exchange a verified Keycloak token for a
Firebase custom auth token (Firestore has no native Keycloak/OIDC
verification), then real per-user `request.auth.uid`-scoped rules. Not
started yet — tracked in `TASKS.md`.

## Known issues / tech debt

- Firestore rules are open (time-boxed) with no per-user auth — see above.
- `lib/firebase_options.dart` is a placeholder; run `flutterfire configure`
  before shipping to a real device/project.
