# Implementation Prompt — Rebuild the app's UI/UX from the verified design

Paste everything below into a new Claude Code session in this repo (`greyvetro-budget-tracker`).

---

## Prompt

We designed and verified a new information architecture for this Flutter app in a Claude Design artifact:
https://claude.ai/design/p/f968a725-e0b1-475e-aa04-06f203d51195?file=Greyvetro+Budget+Tracker.dc.html&via=share
(Viewing it interactively requires my claude.ai login via the Chrome extension — if you can't reach it, the spec below is the full source of truth; it was written from directly testing every screen in that artifact.)

That artifact was built from `REDESIGN_PROMPT.md` (the original brief) and iterated on via `DESIGN_FIX_PROMPT.md` (a fix list), both already in this repo — read them for full background and rationale. The artifact has now been verified to fully and correctly implement the new IA. Your job this session is to port that IA and interaction pattern into the real Flutter app in `lib/features/net_worth/ui/`, replacing the current push-navigation shell. This is a restructuring of navigation and presentation, not a rewrite of business logic — most of the underlying functionality already exists and is correct.

### What's already correct — do NOT rewrite
- Data models (`Account`, `MonthlyEntry`, `MonthSummary`) and `BudgetRepository` / `FirestoreBudgetRepository`.
- `CashCounterSheet` and its existing wiring: the Add Account "Cash denomination counter" toggle, the per-row calculator toggle in Manage Accounts, and the calculator shortcut icon in Month Detail. This all already works.
- Non-negative balance enforcement on the numeric input fields (`FilteringTextInputFormatter` already blocks the minus sign) — don't loosen it.
- `DashboardScreen`'s four charts (net worth trend, assets vs. reserved & liabilities, monthly saved, latest balance breakdown) and their logic — these are complete and correct, they just need to move under the new nav shell instead of being a pushed route.
- Light/dark color seeds in `main.dart` (`#3E9AC4` light / `#8FD0E8` dark) — keep them, just add a user-facing `ThemeMode` override on top.

### 1. Persistent bottom navigation + drawer shell (currently missing)
- Add a top-level shell widget with a `NavigationBar` (3 destinations: **Home**, **Dashboard**, **Accounts**), each preserving its own navigation/scroll state. `MonthListScreen`, `DashboardScreen`, and `ManageAccountsScreen` become the bodies of those three tabs instead of separately pushed routes.
- Remove the old AppBar icon buttons in `MonthListScreen` that currently push to Dashboard (`Icons.insights`) and Manage Accounts (`Icons.settings_outlined`) — replace with the bottom nav plus a hamburger drawer icon.
- **Drawer** (opened from Home's app bar), top to bottom: header showing app name + current net savings as a quick glance, **Settings**, **Export / Backup data** (placeholder screen/action is fine), **Help / About**, and a disabled **Sign out** row labeled "Soon" (reserved slot for future Keycloak SSO — no functional sign-out flow).
- **Settings screen** reachable from the drawer: an Appearance segmented control (Light / Dark / System) that actually drives the app's `ThemeMode` — introduce a small piece of state at the `MaterialApp` root (e.g. a `ValueNotifier<ThemeMode>` passed down, or `ChangeNotifier` — no new package needed) so switching it live-updates the whole app. Below it, a "Currency & locale" row marked "Coming soon" (non-interactive placeholder for now).

### 2. Bottom sheets instead of full-screen forms (currently full-screen/dialog)
- **Add Account**: convert from the current `AlertDialog` (in `manage_accounts_screen.dart`) to a modal bottom sheet matching `CashCounterSheet`'s existing pattern — drag handle, `isScrollControlled: true`, capped at ~90% of screen height, scrolls if content overflows. Keep the exact same fields/logic (Name, Section toggle, conditional Kind, conditional Cash counter toggle) — only the container changes.
- **Month Detail**: convert from the current pushed `Scaffold` route (`month_detail_screen.dart`) into a large `DraggableScrollableSheet`-based modal launched from Home, expandable near-fullscreen. The live summary bar (Total Assets / Reserved & Liabilities / Net Savings / current month saved) must stay pinned at the bottom of the sheet while the user scrolls/types. Keep the underlying Home screen visible/dimmed behind it where feasible.

### 3. Month List row is missing the % change
`_MonthTile` in `month_list_screen.dart` currently shows only the ₱ delta (e.g. `+₱9,050.00`). Add the % change next to it using the already-computed `MonthSummary.momChangePct`, formatted the same way the Month Detail summary bar already does it: `+₱9,050.00 (+5.7%)` / `-₱550.00 (-0.4%)`.

---

### Acceptance checklist
- [ ] Bottom nav switches between Home / Dashboard / Accounts without losing each tab's own state
- [ ] Drawer opens from Home and shows, in order: header + net savings snapshot, Settings, Export/Backup, Help/About, disabled "Sign out (Soon)"
- [ ] Settings screen: Light/Dark/System actually changes the live app theme; "Currency & locale" shows as "Coming soon"
- [ ] Add Account is a bottom sheet (drag handle, scrollable, capped height), not a dialog
- [ ] Month editing is a draggable bottom sheet, not a pushed screen, with the live summary pinned while open
- [ ] Month List rows show `+₱X (+Y%)` / `-₱X (-Y%)`, not just the ₱ amount
- [ ] Cash Counter, the non-negative balance rule, and all 4 Dashboard charts still work exactly as before — no regressions
- [ ] Light/dark parity holds across every screen, including the new drawer and settings screen
