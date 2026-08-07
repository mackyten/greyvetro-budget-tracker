# Privacy Policy — Greyvetro Budget Tracker

**Effective:** 7 August 2026
**Applies to:** Android app, all versions from 1.0.0
**Controller:** Greyvetro
**Contact:** macky@greyvetro.com

Canonical, publicly hosted copy (this is the URL to submit in Play Console → App content →
Privacy policy): https://greyvetro-budget-tracker.web.app/privacy
— served from `public/privacy/index.html` in this repo via Firebase Hosting
(`firebase deploy --only hosting`). Once `greyvetro.com` is mapped to this Hosting site
(Firebase Console → Hosting → Add custom domain → DNS records added at Hostinger), the policy
will also be reachable at https://greyvetro.com/privacy — update this line and the Play Console
listing to that URL once the domain mapping is live.

## Overview

Greyvetro Budget Tracker is a personal net worth and liquidity tracker for
Android, built by Greyvetro. This policy explains what the app collects,
why, where it's stored, and who — if anyone — it's shared with. It covers
every permission and data type the app actually requests.

The short version: your financial figures sync to a private, per-account
Firestore database so you can rely on them across sessions. Anything more
sensitive — card numbers, passwords, your app-lock PIN — is deliberately
kept off that sync path and never leaves your device. The app shows ads
served by Google AdMob (except to the developer's own account, which keeps
them off during day-to-day use); your financial data is never shared with
AdMob or any advertiser — see **Advertising**, below, for exactly what the
ad SDK does and doesn't see. There are no analytics trackers and no data
brokers anywhere in this app.

## Summary

| Data | Purpose | Stored |
|---|---|---|
| Email & name | Sign you in, scope your data to your account | Google Sign-In |
| Account balances & notes | The core budget-tracking feature | Cloud · Firestore |
| Vault items (cards, passwords) | Optional Secure Vault storage | On-device only |
| App-lock PIN | Locks the app; stored as a salted hash, not the PIN itself | On-device only |
| Fingerprint / face | Biometric unlock | Never leaves OS |
| Microphone audio | Optional voice balance entry | Not recorded/stored |
| Advertising ID & ad interaction data | Serving ads via Google AdMob | Collected by Google, not us |

## What we collect

**Account information.** You sign in with Google. We receive your email
address and display name from Google Sign-In, via Firebase Authentication.
This identifies your account and is the key everything else
is scoped to — it is not used for marketing and never shared with
advertisers.

**Financial tracking data you enter.** Account names, monthly balances, and
any notes you add are the core of the app. They're written to a private
Cloud Firestore database under a path scoped to your account
(`users/<your-id>/…`), enforced by server-side security rules — no other
user's app instance can read or write your entries, and vice versa.

**Secure Vault data.** The optional Vault lets you store bank card details,
Wi-Fi passwords, and similar notes for your own reference. Vault entries are
written only to your device's hardware-backed secure storage (Android
Keystore) and are never transmitted anywhere — not to Greyvetro, not to
Firebase, not to Google. If you uninstall the app or lose the device, Vault
data cannot be recovered by us, because we never had it.

**App-lock PIN & biometrics.** Your PIN is stored as a salted SHA-256 hash
in the same on-device secure storage as the Vault — the actual digits you
type are never saved or transmitted. Biometric unlock (fingerprint or face)
is handled entirely by Android's own biometric APIs; the app only ever
receives a yes/no result from the OS and never has access to your biometric
data itself.

**Microphone.** If you use voice balance entry, the app requests microphone
access for that single interaction and hands the audio to Android's system
speech-recognition service to produce text. The app itself does not record,
store, or transmit audio, and the permission is only requested when you tap
the microphone button.

**Notifications & home-screen widget.** A local, on-device reminder can
prompt you to log your month-end balances near the end of each month. The
optional home-screen widget reads your latest net worth figure from local
app storage to display it. Neither feature sends anything off your device.

## How your information is used

- To authenticate you and keep your financial data private to your account.
- To sync your entries across app sessions and, if you reinstall, restore
  them.
- To power features you explicitly opt into — voice entry, reminders, the
  widget, biometric unlock.
- Your financial data (balances, notes, Vault, PIN) is never used for
  advertising, profiling, or resale, and we do not run any analytics SDK
  that tracks your behavior in the app. Separately, the app displays ads
  via Google AdMob — see **Advertising**, below.

## Where it's stored, and who can see it

Cloud-synced data (your account list and monthly entries) lives in Google
Firebase (Cloud Firestore and Authentication), which acts as Greyvetro's
infrastructure provider. It's encrypted in transit (TLS) and at rest by
Firebase's own infrastructure. Security rules restrict every read and write
to the signed-in owner of that data — Greyvetro's developer does not browse
individual users' financial entries as a matter of course, and only
accesses them if needed to debug an issue you've reported, or if legally
required to.

Vault entries, your PIN hash, and widget/reminder state stay entirely on
your device, inside Android's Keystore-backed secure storage — the same
mechanism Android uses to protect saved passwords and payment credentials
system-wide.

## Advertising

The app shows ads served by **Google AdMob** to fund development. This is
entirely separate from your financial data:

- AdMob never receives your email, name, account balances, notes, Vault
  contents, or PIN — none of that data path touches the ads SDK.
- To serve and measure ads, the AdMob SDK on your device collects data
  standard to mobile advertising: your device's advertising ID, IP-derived
  approximate location, device/app info, and ad interaction data (views,
  clicks). Google acts as an independent controller for this data under its
  own [Privacy Policy](https://policies.google.com/privacy) and
  [how Google uses data when you use partner sites/apps](https://policies.google.com/technologies/partner-sites).
- Where required by law (EEA, UK, Switzerland, and other regulated
  regions), the app runs Google's User Messaging Platform (UMP) consent
  flow before requesting any ad, and no ad is requested until that flow
  completes. You can review or change your choice any time from
  **Settings → Ad privacy options** (shown only where applicable).
- The developer's own account has ads switched off by default while using
  the app day-to-day, and only enables them briefly to preview what real
  users see — interacting with your own live ads violates AdMob policy.
- Ads only render on Android/iOS; there are no ads on macOS or web builds
  of this app.

## Third parties

The two third parties involved in running this app are Google, as the
provider of Firebase (hosting, database, authentication) and Google
Sign-In, and Google AdMob, which serves ads as described above. We do not
sell data or share it with data brokers, and we do not run any
third-party analytics SDK — the only network calls the app makes beyond
your own Firebase project are the ad requests AdMob's SDK makes on your
device.

## Data retention

Cloud-synced data is kept until you delete it or ask us to delete your
account (see Your choices below). On-device data — Vault, PIN hash, cached
widget values — is deleted immediately and permanently the moment you
uninstall the app, since it was never copied anywhere else.

## Your choices

- **Export.** You can export a copy of your tracked data as CSV or PDF at
  any time from Settings.
- **Delete individual entries** directly in the app — archiving an account
  or clearing a month's figures removes them from Firestore immediately.
- **Delete your account.** You can delete your account and all synced data
  directly in the app, from Settings → Delete account. If you no longer have
  the app installed, email macky@greyvetro.com from the address associated
  with your Google account and we'll erase your Firestore data (accounts,
  monthly entries, profile link) within 30 days, and confirm once it's done.
- **Vault & PIN data** live only on your device, so deleting them is as
  simple as clearing the app's storage or uninstalling — there's nothing on
  our end to remove.

## Security

- All network traffic to Firebase is encrypted with TLS.
- Cloud Firestore data is encrypted at rest by Google's infrastructure.
- On-device secrets (Vault, PIN hash) use Android's hardware-backed
  Keystore via `flutter_secure_storage` — not plain files, not
  `SharedPreferences`.
- Your PIN is salted and hashed (SHA-256); the raw PIN is never persisted.
- Firestore security rules enforce per-user access control at the database
  level, independent of the app's own logic.

## Children's privacy

This app is intended for general audiences managing their own personal
finances and is not directed at children under 13. We do not knowingly
collect data from children. If you believe a child has provided us data,
contact us and we'll remove it.

## Changes to this policy

If this policy changes, we'll update the effective date above and, for
material changes, note it in the app's release notes. Continued use of the
app after a change means you accept the updated policy.

## Contact

Questions, data requests, or concerns: macky@greyvetro.com.
