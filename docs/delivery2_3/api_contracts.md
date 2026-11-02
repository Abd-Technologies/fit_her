# Delivery 2–3 — API contracts (Flutter-first)

Flutter ships local adapters now. Backend should implement these shapes later.

## Remote controls (2P5)

`GET /config/remote-controls` → same shape as `assets/remote/remote_controls_v1.json`.

## Food preferences (2NH1)

`PUT /users/food-preferences`

```json
{
  "dietType": "halal|vegetarian|vegan|dairy_free|omnivore|custom",
  "allergies": ["nuts", "dairy"],
  "dislikes": ["bitter gourd"]
}
```

## Extended check-in (2NH5 / 2NH6)

Extend `POST /users/daily_checkin` with:

```json
{
  "hunger": 1,
  "cravings": ["sweet"],
  "digestion": "bloated",
  "digestionNote": "optional"
}
```

## Medications (2NH7)

`GET|POST|PATCH /users/medications` — never return dose advice fields from server AI.

## Period flow (2NH8)

`POST /users/period-flow` `{ "date", "flow", "clots", "pain" }`

## Skin/hair (2NH9)

`POST /users/skin-hair` `{ "date", "severities": { "acne": 2 } }`

## Weekly diet adjust (2NH3)

`POST /diet/weekly-adjust` → `{ "weekOf", "changes": [], "note", "calorieFloor" }`

## Grocery (2NH4)

`POST /diet/grocery` from active plan → aisle-grouped list with optional `phaseSwap`.

## Reports (2NH10–13)

- `GET /reports/weekly-pattern`
- `GET /reports/weekly-recap`
- `GET /reports/monthly`
- `GET /reports/doctor-pdf` (gate from remote `doctorPdfGate`)

## Period predictor (2NH14)

`GET /cycle/prediction` → `{ "rangeStart", "rangeEnd", "expectedLengthDays", "expectedHeaviness", "usualSymptoms", "irregular", "sharpChangePrompt" }`

## Recorded library (3M1–3M8)

- `GET /library/classes`
- `POST /library/progress` `{ "classId", "position" }`
- `POST /admin/library/publish` (multipart)
- `POST /admin/library/import-replay` (3M5 stub)

## Entitlements (3M3 / X4)

`GET /users/tier-access` → `{ "tier": "free|active|plus|unlimited", "libraryAccess": "none|subset|full", ... }`

## Nutritionist (3NH1)

`POST /nutritionist/chat` `{ "message" }` → `{ "reply", "remainingDaily", "costUnits" }`

## Condition modules (3H1+)

`GET /conditions/modules` (config JSON)  
`PUT /users/conditions` `{ "activeIds": ["pcos"] }`  
Module-specific: pain diary, TTC log, PMS ratings, peri symptoms, labs.

## Platform

- Referral: `POST /referral/invite`, `POST /referral/redeem`
- Gift: `POST /plans/gift`
- Group: `POST /plans/group/join`
- Health sync: `POST /health/sync` (steps/sleep/HR)
- Points: `GET /points`, `POST /points/redeem`

## Privacy / locale

Client-only for PIN lock; server stores `locale` preference and discreet notification flag.
