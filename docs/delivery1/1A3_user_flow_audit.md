# 1A3 — User flow audit (Flutter)

## Funnel map

Install → Signup → Onboarding → First log (check-in/symptoms) → First guided workout → Paywall → Payment

## Drop-offs addressed in D1 Flutter

1. Fragmented daily logging → `DailyFocusCard` + quick check-in sheet
2. Locked Luna confusion → Free phase message + “what Plus adds”
3. Missed class dead-end → `MissedSessionSheet` → guided workout
4. Community safety → report/block/anonymous + client scan

## Severity 1–2 closed in app

- Progress symptoms no longer static when local logs exist
- Meal photo Free cap + upgrade dialog
- Anonymous posting toggle on create post
