# 1A2 — Payment flow audit (Flutter)

## Paths checked (Wave 0 + D1)

1. Plans → Subscribe → slip upload (camera/gallery) → pending status
2. Plans → trial banner → TrialOnboardingScreen
3. Refund policy link on OurPlansScreen
4. Instant activation banner (`InstantActivationBanner`) polls when `d1_payment_pending`

## Findings

| Severity | Finding | Flutter fix |
|---|---|---|
| Closed (W0) | Slip toast while picker open | upload_slip_screen rewrite |
| Closed (W0) | Identical paywall bullets | V2PriceCard featuresForPlan |
| Open (backend) | Instant JazzCash/Easypaisa | 1P6 UI ready; gateway later |
| Open | Plan-active push copy | Contract in api_contracts.md |

## Events wired

`paywall_view`, `upgrade_tap`, `payment_success`, `payment_failure` via `AnalyticsEvents`.
