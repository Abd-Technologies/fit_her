# Wave 0 handoff (v13.0.x stabilize)

## Shipped in code

### Track A — Build / security
- `android/app/build.gradle`: `ndk.abiFilters` arm64-v8a + armeabi-v7a; Play Bundle language/density/abi splits enabled.
- `AndroidManifest.xml`: strip CALL_PHONE, READ_PHONE_STATE, AD_ID / adservices, Zebra/EMDK via `tools:node="remove"`. `SYSTEM_ALERT_WINDOW` kept for Zoom overlay.
- **Release:** use `flutter build appbundle --release` (not a universal APK).

### Track B — Payment / paywall
- P-01: `upload_slip_screen.dart` rewritten — inline errors (no toast while picker open), loading on submit, status line, delayed picker open after permission.
- Paywall: `V2PriceCard` Most Popular / lighter workout-only cards; feature bullets from plan text (`featuresForPlan`).
- Refund link on `OurPlansScreen`; benefit chips reworded (no “Early Detection”).
- Trial: banner on plans screen + link into `TrialOnboardingScreen` (existing funnel). Full trial-on-plan-card product is not invented here.

### Track C — Critical bugs
- Greeting sanitizer: `lib/utils/display_name.dart` (Diet / paid / unpaid heroes).
- Day counter: plan-ended state instead of “Day 13 of 7”.
- Stacked sheets: reminder closes before booking; orchestrator keeps `_showing` across handoff.
- Mark All Read: neutral green-gray (not red).
- Progress: hide “Meals · coming soon” placeholder.
- Dual FABs: none mounted on bottom bar (confirmed).

### Track D — Trust
- Team/Admin button removed from login; **long-press logo** opens staff role picker.
- Signup: tappable Terms (WebView) + Privacy; short health-data blurb.
- Profile menu: “Privacy & health data” → `PrivacyHealthNoticeScreen`.

## Manual QA checklist
- [ ] Slip: camera + gallery on Android; error only if dismissed empty; upload spinner + success copy
- [ ] Our Plans: recommended badge, workout-only without diet bullet, refund link, trial banner when unpaid
- [ ] Login: no Team/Admin CTA; long-press logo → role sheet still works
- [ ] Diet hero: no “Hi last”; ended plan shows “Plan completed”
- [ ] Day7 / Book reminder: never two sheets at once
- [ ] Notifications: Mark All Read is not red
- [ ] Signup + Profile open privacy notice
- [ ] `flutter build appbundle --release` and confirm AAB size / merged manifest permissions

## Client note
Wave 0 is stabilize only. Delivery 1 (Luna, food DB, guided workouts, etc.) starts after this release sign-off.
