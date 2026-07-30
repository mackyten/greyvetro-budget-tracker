# Redesign Prompt — Greyvetro Budget Tracker

Copy everything below into your design tool of choice (Claude, Figma AI, etc.) as the brief.

---

## Prompt

You are redesigning the UI/UX of **Greyvetro Budget Tracker**, an Android app (Flutter, Material 3) that replaces a personal "Net Worth / Liquidity Tracker" spreadsheet. It's a single-user, monthly net-worth and cash-flow tracker: once a month the user opens the app, types in the current balance of every bank account, e-wallet, investment, reserved fund, and credit card they have, and the app computes their total assets, total liabilities, net savings, and how that changed since last month.

This is a **redesign of the information architecture and interaction patterns**, not a rebuild from scratch — every feature listed below must survive the redesign in some form. Nothing here is decorative-only; each screen/field maps to real persisted data. Treat the "Current Feature Inventory" section as a checklist that must map 1:1 onto the new design.

### Platform constraints

- **Framework:** Flutter, Material 3 (`useMaterial3: true`), must map cleanly onto standard Flutter widgets (`Scaffold`, `NavigationBar`/`BottomNavigationBar`, `Drawer`, `showModalBottomSheet`, `DraggableScrollableSheet`).
- **Form factor:** Android phones, portrait-first.
- **Themes:** Both a light theme (seed color `#3E9AC4`) and a dark theme (seed color `#8FD0E8`) are supported today — the redesign must keep full light/dark parity, not just a light mockup with a dark mode as an afterthought.
- **Currency/locale:** Philippine Peso (₱), `en_PH` locale, full currency format for line items (`₱12,345.67`) and compact format for chart axes (`₱1.2K`). Months are displayed as `MMMM yyyy` (e.g. "July 2026").
- **Backend:** Firebase Firestore, read via real-time streams — screens should assume data can change under them and already show loading states while streams connect. (A future phase will add Keycloak/SSO-based per-user auth in front of this; don't design a login screen now, but don't preclude one either.)

---

### Current Feature Inventory (must not be lost)

**1. Month List (current home screen)**
- Reverse-chronological list of every tracked month.
- Each row shows: month name, Total Assets, Total Reserved & Liabilities, Net Savings (large/bold), and the delta vs. the previous month (colored green if positive, red if negative, shown as `+₱X` or `-₱X` with a % change).
- Empty state: "No months tracked yet."
- Primary action: add the next month (auto-computed as one month after the latest tracked month, or the current month if none exist yet). If that month already has data, reopen it instead of creating a duplicate.
- Tapping a row opens that month for editing.

**2. Month Detail / Entry (the core data-entry flow)**
- Editing one month's balances, grouped into two sections: **Assets** and **Reserved & Liabilities**.
- Each account row: an icon (differs for asset / reserved fund / credit card), the account name, and a numeric currency input (2 decimal places, ₱ prefix).
- **Sign convention (non-negotiable — do not add a +/- toggle or negative-number styling):** every balance, in every section, is entered as a non-negative magnitude. Credit card balances mean "amount currently owed," reserved-fund balances mean "amount set aside" — both are positive numbers, and both get *subtracted* from Total Assets to reach Net Savings. This isn't a pure net-worth sheet; it's a *liquidity* tracker, so money that's earmarked (reserved funds) is deliberately treated the same as money that's owed (credit cards) — both reduce what's actually free to spend. The input must never accept a minus sign.
- Only "active" accounts are shown, **plus** any archived account that already has a balance recorded for that specific month (so historical months stay intact even after an account is archived).
- Optional free-text **Note** field for the month (multi-line).
- A **live-updating summary** (Total Assets, Total Reserved & Liabilities, Net Savings, current month's saved amount + % change vs. previous month) recomputes on every keystroke, before saving — the user must be able to see running totals while still typing, not just after they save.
- Explicit Save action; must confirm the save completed (or show a spinner while in flight) before returning to the list.
- Any asset account flagged with a "cash counter" gets a shortcut icon next to its balance field that opens the **Cash Counter** (see below) and pre-fills the balance with its result.

**3. Cash Counter (already a modal bottom sheet today — keep this pattern, extend it elsewhere)**
- A standalone denomination calculator for counting physical peso cash: ₱1000, ₱500, ₱200, ₱100, ₱50, ₱20 (bill), ₱20 (coin), ₱10 (coin), ₱5 (coin), ₱1 (coin).
- Each denomination has a quantity input and a live subtotal; a running grand Total at the bottom.
- "Clear" action resets all quantities.
- "Use total" commits the computed total back to the balance field that launched it.
- Must resize correctly above the keyboard and scroll if content exceeds screen height.

**4. Manage Accounts**
- List of all accounts grouped by section (**Assets**, **Reserved & Liabilities**), in a user-defined manual order.
- Each account shows: name (struck through if archived/inactive), and for Reserved & Liabilities accounts, its kind ("Reserved fund" or "Credit card").
- Per-row controls: an Active/Archived toggle (accounts are **never hard-deleted** — archiving preserves all historical months' data), and for asset accounts, a toggle for whether the cash-denomination-counter shortcut appears for that account.
- Add-account action captures: name, section (Asset / Reserved & Liability), kind (only if Reserved & Liability: Reserved fund vs. Credit card), and whether to enable the cash counter (only offered for Asset accounts). A unique ID and next sort order are derived automatically — no user-facing ID field.

**5. Dashboard (analytics)**
- **Net worth over time** — single-line trend of Net Savings across all tracked months (needs ≥2 months of data, otherwise show an empty-state hint).
- **Assets vs. Reserved & Liabilities** — two-line comparison chart on one shared amount axis, with a legend (this is the one place two distinct named series appear together, so it's the one chart allowed a second brand-independent color).
- **Monthly saved amount** — bar chart of the signed month-over-month delta, bars colored green above zero / red below zero.
- **Latest balance breakdown** — ranked horizontal bar list of the current balance of every active asset account (largest first; zero/blank balances excluded) — deliberately a bar list, not a pie/donut, since it can have a dozen-plus long-named accounts.
- All charts need sensible empty/insufficient-data states, and axis labels that never overlap (adaptive tick spacing, compact currency on the amount axis).

**Data model reference** (so the redesign accounts for every field that needs a UI home):
- **Account:** id, name, section (asset | reservedLiability), reservedKind (reserved | creditCard — reserved/liability only), manual sort order, active/archived flag, cashCounter flag (asset-only).
- **MonthlyEntry:** month, sparse map of accountId → balance (a missing key is a genuinely blank cell, not zero), optional note.
- **MonthSummary (always computed, never edited directly):** total assets, total reserved & liabilities, net savings, current month's saved amount vs. previous month, % change vs. previous month.

---

### Redesign Requirements

**A. Add a persistent Navigation Bar + Side Drawer**

Today navigation is a stack of pushed screens with two ad hoc `AppBar` icon buttons. Replace it with:

1. **Bottom navigation bar** with 3 top-level, always-reachable destinations (each keeps its own navigation state):
   - **Home** — the Month List (reverse-chronological months + the "add next month" action).
   - **Dashboard** — the analytics charts.
   - **Accounts** — Manage Accounts.
   
   Rationale: these are the three screens the user actually visits regularly, and none of them is naturally "nested" inside another, so they belong at the top level rather than behind a menu.

2. **Side drawer** (hamburger, opened from Home's app bar) for secondary, lower-frequency items that don't need one-tap access:
   - App header (app name + current net savings snapshot as a quick glance).
   - **Settings** — theme (light/dark/system), and room for currency/locale display preferences later.
   - **Export / Backup data** (placeholder is fine if not wired up yet — but give it a home).
   - **Help / About**.
   - A reserved slot for **Sign out / Account** once Keycloak SSO lands — don't build the flow, just leave the pattern extensible.
   
   Rationale: this keeps the bottom bar uncluttered (3 items, no ambiguity about which tab you're on) while giving infrequent, global-scope actions a discoverable home instead of overloading app bar icons.

Don't duplicate Home/Dashboard/Accounts inside the drawer — the bottom bar already owns those; the drawer is strictly for things that aren't one of the three primary destinations.

**B. Use bottom sheets / modals for data input — not full-screen forms**

The explicit goal is to stop cramming input forms into the primary screen flow. Apply this to every data-entry moment:

- **Add Account** (currently a plain `AlertDialog`) → a bottom sheet form (name, section, conditional kind/cash-counter fields), matching the Cash Counter's existing sheet treatment.
- **Cash Counter** → already a modal bottom sheet; keep it, and use it as the reference pattern (drag handle, `isScrollControlled`, resizes above the keyboard, scrolls if content overflows, capped at ~90% of screen height) for every other sheet you design.
- **Editing a month's balances** → this is the densest form in the app (up to dozens of accounts + note + live summary). Present it as a large, draggable modal sheet (e.g. `DraggableScrollableSheet`, expandable near-fullscreen) rather than a separate pushed screen, so it visually reads as "temporarily editing a record" rather than "a whole new place in the app." The live summary must stay visible/pinned while the sheet is open and the user is typing.
- **Editing the month's note** can be inline within that same sheet, or its own small modal if that reads cleaner — your call, as long as it doesn't require leaving the balances sheet entirely.

Keep the underlying screen visible/dimmed behind the sheet where feasible, so context isn't lost.

**C. Visual language**

- Keep Material 3 with full light/dark support; you may propose a refreshed palette/typography, but preserve the *semantic* color conventions already in place: green = positive/saved, red = negative/lost, and the existing colorblind-safe two-series chart palette (blue/orange) used only where two named series share a chart.
- Icons should keep distinguishing asset vs. reserved-fund vs. credit-card accounts at a glance (as today), and archived accounts should remain visually distinct (not just a switch state) wherever they appear.

---

### Deliverables

For each of the 3 primary destinations (Home, Dashboard, Accounts) plus the 3 sheet-based flows (Add/Edit Month, Add Account, Cash Counter), and the Drawer:

1. A screen/sheet-level layout (wireframe or high-fidelity, your call) in both light and dark.
2. States: empty, loading, and populated — at minimum for Home and Dashboard.
3. Interaction notes for the sheets specifically: trigger point, expand/collapse behavior, keyboard handling, and how the result (e.g. a computed cash total, a newly added account) hands off back to the screen that launched it.
4. A short IA diagram showing the bottom nav + drawer structure relative to the sheets (which sheets can be launched from which tab).

Do not introduce new top-level screens beyond Home / Dashboard / Accounts, and do not remove any field, toggle, or computed value listed in the Feature Inventory above — if something seems redundant, flag it as a question rather than silently dropping it.
