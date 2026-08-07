# Play Console submission prep

Pre-filled answers for the forms you'll fill out once your developer account
is verified. Goal: submission day is copy-paste, not decision-making.

## 0. Closed testing (the actual bottleneck)

New developer accounts (personal — and now most organization accounts too)
can't reach Production until:

- A **Closed testing** track (not Internal testing — that doesn't count)
- has **≥ 12 testers opted in**
- who've been enrolled **continuously for ≥ 14 days**

This runs independently of identity verification and is usually the slower
of the two. Start recruiting testers now (opt-in link goes out once the
Console lets you create the track) so the 14-day clock starts the moment
you're verified — friends/colleagues, or a testing-swap community (e.g.
r/androidapps "testers wanted" threads) if you need to hit 12.

## 1. Privacy policy URL

```
https://greyvetro-budget-tracker.web.app/privacy
```
(anchor for the account-deletion section specifically:
`https://greyvetro-budget-tracker.web.app/privacy#delete-your-account`)

## 2. Data safety form (App content → Data safety)

**Does your app collect or share any of the required user data types?** Yes

| Category | Type | Collected? | Shared? | Purpose | Optional? |
|---|---|---|---|---|---|
| Personal info | Email address | Yes | No | Account management | Required (sign-in) |
| Personal info | Name | Yes | No | Account management | Required (sign-in) |
| Financial info | Other financial info (user-entered balances/notes) | Yes | No | App functionality | Required (core feature) |
| Audio | Voice or sound recordings | Yes* | No | App functionality | Optional |
| App activity | App interactions, ads data (AdMob) | Yes† | Yes† | Advertising or marketing | Optional (consent-gated in EEA/UK/CH) |
| Device or other IDs | Advertising ID (AdMob) | Yes† | Yes† | Advertising or marketing | Optional (consent-gated in EEA/UK/CH) |

\* Mic audio is processed transiently by Android's on-device speech
recognizer for voice balance entry; the app itself never records, stores,
or transmits it. Answer "Collected" (Play counts transient access) but you
can note "not stored" in the description field, and leave "shared" as No.

† Google AdMob (banner ads) collects and shares device/advertising
identifiers and ad interaction data for ad serving and measurement — this
never includes the app's own financial data (balances, notes, Vault, PIN),
which stays entirely out of the ads data path. A UMP consent flow gates ad
requests in the EEA/UK/Switzerland. Declare purpose as "Advertising or
marketing"; do **not** declare "App functionality" for this row.

**Is all user data encrypted in transit?** Yes (TLS to Firebase)

**Do you provide a way for users to request data deletion?** Yes — in-app
(Settings → Delete account) and via web
(`.../privacy#delete-your-account`)

**Data retention:** cloud data kept until deleted by user or on request;
on-device data (Vault, PIN hash) deleted on uninstall.

Not applicable / leave unchecked: Location, Photos/Videos, Health &
fitness, Messages, Web browsing history, Purchase history, Credit score,
Contacts, Calendar.

## 3. Content rating questionnaire

Category: **Utility / Productivity / Finance** (pick "Finance" if offered
as a distinct category — this is a personal tracker, not a
lending/payments/crypto product).

Expected answers (all "No"): violence, sexual content, profanity, drugs,
gambling, user-generated content shared with others, unmoderated chat,
location sharing, ability to purchase digital goods. → Should resolve to
**Everyone**.

## 4. Target audience & content

- Target age group: **18+** (financial app; also sidesteps
  Families-policy scrutiny entirely since it's not targeted at children)
- Ads: **Yes** — banner ads via Google AdMob (`google_mobile_ads`), gated
  behind a UMP consent flow where legally required. Also declare this under
  App content → Ads.
- In-app purchases: **None**
- News app: No · COVID-19 app: No · Government app: No
- **Financial features declaration**: this app does **not** need it —
  that's for lending, crypto exchanges, payment processing, etc. Manual
  net-worth tracking with no money movement doesn't qualify.

## 5. Store listing copy

**App name:** Greyvetro Budget Tracker

**Short description** (68/80 chars):
> Track your net worth privately — no analytics, no data resale, ever.

**Full description** (draft — edit freely, well under the 4000-char cap):
> Greyvetro Budget Tracker is a simple, private net worth and liquidity
> tracker. Log your account balances each month and watch your net worth
> trend over time — no linked bank accounts, no analytics, no data
> brokers.
>
> • Monthly balance tracking across assets and reserved funds/liabilities
> • Net worth trend chart and month-over-month savings %
> • Optional Secure Vault for card/Wi-Fi notes — stored only on your
>   device, never synced
> • App lock via PIN or biometric unlock
> • Voice entry for quick balance updates
> • Home-screen widget showing your latest net worth
> • Export your data anytime as CSV or PDF
> • Sign in with Google — your data is private to your account, encrypted
>   in transit and at rest
>
> This app is supported by banner ads. Your financial data — balances,
> notes, Vault, PIN — is never shared with our ad partner. No analytics
> SDKs. No data resale. Ever.

**Category:** Finance (or Productivity, if Finance requires
additional business verification you'd rather skip initially — check what
Play Console actually asks for when you get there)

## 6. Store listing graphics still needed (not generatable from code)

- ✅ Hi-res icon (512×512, 32-bit PNG w/ alpha) — generated, see
  `store_assets/play_store_icon_512.png` (sourced from
  `logos/greyvetro-appicon-dark.png`)
- ✅ Phone screenshots — captured live from the RMX3461 on real account
  data, in `store_assets/screenshots/`: `1_dashboard.jpg` (net worth +
  trend chart), `2_snapshots.jpg` (monthly history), `3_month_detail.jpg`
  (balance entry w/ voice input), `4_manage_accounts.jpg` (multi-account
  list). Pillarboxed to 1280×2412 (ratio 1.88, under Play's 2:1 cap —
  the device's native 1080×2412 is 2.23:1 and would've been rejected on
  upload) and saved as JPEG (no alpha channel, per spec).
- ❌ Feature graphic (1024×500, JPG/PNG no alpha) — needs actual design
  work, nothing in `logos/`/`assets/branding/` matches this aspect ratio
