# Delivery 1 — API contracts (Flutter-first)

Flutter ships local adapters now. Backend should implement these shapes later.

## Daily check-in (extended)

`POST /users/daily_checkin`

```json
{
  "date": "2026-11-02",
  "moodLevel": 1-5,
  "energyLevel": 1-5,
  "stressLevel": 1-5,
  "stressCause": "work|family|health|money|other",
  "sleepHours": 7.5,
  "sleepRested": 1-3,
  "cyclePhase": "follicular"
}
```

## Symptoms

`POST /users/symptoms` · `GET /users/symptoms?from=&to=`

```json
{
  "date": "2026-11-02",
  "cyclePhase": "luteal",
  "severities": { "cramps": 2, "bloating": 1 },
  "painBodyArea": "lower_abdomen"
}
```

Editable for 48 hours after `updatedAt`.

## Food DB

`GET /foods/pk?version=` — returns versioned dish list matching `assets/food/pakistani_foods.json`.

## Meal photo

`POST /meals/photo-recognize` (multipart: `photo`)

Response:

```json
{
  "candidates": [{ "foodId": "biryani", "portion": 1.0, "confidence": 0.72 }],
  "remainingThisMonth": 12
}
```

`POST /meals/diary` · `PATCH /meals/diary/:id` for confirm/edit + correction learning.

## Luna batch

`GET /luna/today` — no live LLM on open.

```json
{
  "phase": "...",
  "feel": "...",
  "foodTip": "...",
  "movementTip": "...",
  "sleepNote": "...",
  "builtAt": "ISO-8601"
}
```

## Tier counters (X4)

`GET /users/tier-access` → `{ "isPlus": true, "mealPhotoCap": 30, "mealPhotoUsed": 4, "guidedWorkouts": true, "renewalDate": "..." }`

## Guided workouts

- `GET /guided/exercises`
- `POST /admin/guided-clips` (multipart)
- `POST /guided/sessions` `{ routineId, feedback, completedMoves }`

## Community

- Moderation score on `POST /posts` response: `{ flagged: true }`
- `POST /posts/:id/report` `{ reason }`
- `POST /users/:id/block`
- Anonymous: accept `[anon]` prefix or `anonymous: true`

## Instant activation

Webhook / poll: plan status flip pending → active; push `plan_active`.

## Phase pushes

Server cron using cycle predictions + quiet hours from `/users/notification_preferences`.
