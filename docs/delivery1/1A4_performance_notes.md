# 1A4 — Performance notes (Flutter)

## Measured locally (manual)

- Release AAB path remains `flutter build appbundle --release` (Wave 0 ABI filters).
- Guided player uses timer + static icon (no heavy video decode until CDN clips).
- Food DB loads once from asset JSON (~15 dishes first batch).
- Offline queue is SharedPreferences FIFO (small payloads only).

## Backend later

- Crash reporting already via Sentry; founder dashboard consumes Mixpanel 1A1 events.
- Peak load / capacity test is server-side.
