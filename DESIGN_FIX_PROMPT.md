# Fix Prompt — Greyvetro Budget Tracker (design gap fixes)

Paste everything below into the same Claude Design project/chat (`Greyvetro Budget Tracker.dc.html`) so it can build on top of what's already there instead of starting over.

---

## Prompt

You already redesigned **Greyvetro Budget Tracker** in this project. A review against the original feature inventory found that most of it is solid (Home/Month List, Month Detail, Manage Accounts, the Add Account bottom sheet, and light/dark theme parity all match), but several required pieces are missing or broken. Fix the following, without changing or regressing anything currently working. Keep the visual language you've already established: the same card style used on Home/Manage Accounts, the same bottom-sheet-with-drag-handle pattern used for Add Account, the green/red saved-amount convention, and the blue/orange colorblind-safe pair reserved only for the two-series comparison chart.

### 1. Add the persistent navigation shell (currently missing entirely)
- **Bottom navigation bar** with exactly 3 destinations: **Home** (Month List), **Dashboard**, **Accounts** (Manage Accounts). Each keeps its own navigation state. Remove the old ad-hoc gear icon from the Home app bar now that Accounts lives in the bottom bar — the gear/settings icon should not still open Manage Accounts once it's a bottom-nav tab.
- **Side drawer** (hamburger icon, opened from Home's app bar) containing, in this order: app header (app name + current net savings as a quick glance), **Settings** (theme: light/dark/system — you already have a working dark-mode toggle, fold it into this — plus a placeholder for future currency/locale preferences), **Export / Backup data** (placeholder screen/action is fine), **Help / About**, and a reserved (non-functional) **Sign out / Account** slot for future SSO. Do not duplicate Home/Dashboard/Accounts inside the drawer.

### 2. Build the Dashboard screen (currently missing entirely — no way to reach it)
Four charts, each in its own card, each with a sensible empty/insufficient-data state:
- **Net worth over time** — single-line trend of Net Savings across all tracked months. Needs ≥2 months of data; otherwise show an empty-state hint.
- **Assets vs. Reserved & Liabilities** — two-line comparison on one shared amount axis, with a legend. This is the one chart allowed the second brand-independent color pair (blue/orange).
- **Monthly saved amount** — bar chart of the signed month-over-month delta, bars green above zero / red below zero.
- **Latest balance breakdown** — ranked horizontal bar list (not a pie/donut) of the current balance of every active asset account, largest first, zero/blank balances excluded.
- All axis labels must use adaptive tick spacing and compact currency formatting (₱1.2K-style) so labels never overlap.

### 3. Build the Cash Counter feature (currently missing entirely)
This needs three entry points wired together, plus the modal itself:
- **The modal** (bottom sheet, same drag-handle pattern as Add Account): denominations ₱1000, ₱500, ₱200, ₱100, ₱50, ₱20 (bill), ₱20 (coin), ₱10 (coin), ₱5 (coin), ₱1 (coin), each with a quantity input and live subtotal, plus a running grand Total. A "Clear" action resets all quantities. A "Use total" action commits the computed total back to whatever balance field launched it. Must resize above the keyboard and scroll if content overflows, capped at ~90% of screen height.
- **Add Account sheet**: when Section = Asset, show a toggle/switch for "Cash denomination counter" (this field is currently missing — right now switching to Asset shows no such option at all).
- **Manage Accounts**: for each Asset row, add a per-row control (icon or switch) to enable/disable the cash-counter shortcut for that account — currently there's no such control anywhere in this screen.
- **Month Detail**: for any asset account with the cash-counter flag on, show a small calculator/shortcut icon next to its balance field; tapping it opens the Cash Counter sheet and pre-fills the result back into that balance field on "Use total."

### 4. Fix the sign-convention bug (critical — this is a non-negotiable rule)
Balance input fields currently accept a literal minus sign (I typed `-500` into a balance field and it was accepted and included in the live total). **Every balance in every section must be entered as a non-negative magnitude — the input must never accept a minus sign, in any account row, in any section.** Credit card and reserved-fund balances are always positive numbers that get subtracted from Total Assets elsewhere in the math; don't let the field itself go negative.

### 5. Add the missing % change on Month List rows
Each row's delta currently shows only the ₱ amount (e.g. `+₱9,550.00`). Add the % change next to it, e.g. `+₱9,550.00 (+6.2%)` / `-₱550.00 (-0.4%)`, matching the format already used correctly in the Month Detail summary bar.

### 6. Double-check the "add next month" duplicate logic
There's currently an "August 2026" row seeded with ₱0.00 balances sitting ahead of the latest real month (July 2026) with real data. Confirm this reflects intentional demo/seed data and not a bug where tapping "add month" (or the app's initial state) creates a fresh blank month even when the next month already exists. The correct behavior: computing the next month as one after the latest tracked month (or the current month if none exist), and if that month already has data, reopening it instead of creating a duplicate.

---

### What NOT to touch
Home/Month List's card layout, Month Detail's live summary bar and section/icon treatment, Manage Accounts' active/archived toggle + strikethrough styling, the Add Account bottom sheet's Name/Section/Kind fields, and the existing light/dark theme parity are all correct — don't restructure them, just extend them per the items above.
