# Medify Backend — CLAUDE.md

## Commands

```bash
# Start the database (required before running the app)
docker-compose up -d

# Build all modules
mvn clean install

# Run the application
mvn spring-boot:run -pl app

```

## Architecture

Hexagonal (ports-and-adapters) Maven multi-module project.

```
app → api → domain
      ↓
     data → domain
```

- **domain** — Pure business logic. Models: `Medicine`, `Timing`, `Intake`, `IntakeStatus`, `User`, `CaregiverLink`, `NotificationLog`, `Device`, `DeviceStatus`. Port interfaces: `MedicineRepositoryPort`, `IntakeRepositoryPort`, `NotificationPort`, `DeviceRepositoryPort`, `DeviceConnectionPort`, etc. Schedulers: `ReminderScheduler`, `MissedIntakeScheduler`, `DeviceHeartbeatScheduler`.
- **data** — JPA/Flyway persistence. Each `*Repository` implements its domain port. Migrations in `data/src/main/resources/db/migration/`.
- **api** — REST controllers, services, `NotificationAdapter` (implements `NotificationPort` via static in-memory queue), and the device relay (`api/device/` — `DeviceWebSocketHandler`, `DeviceAuthHandshakeInterceptor`, `DeviceConnectionAdapter`, the latter implementing `DeviceConnectionPort`).
- **app** — Spring Boot entry point only.

## Key Domain Rules

- One `Intake` record is created **per timing window** (not per medicine) when the scheduler fires
- `NotificationPort.send(message, intakeId, timing)` — `timing` is the window name (MORNING/NOON/EVENING), always included so the frontend knows which window to confirm
- Intake status flow: `PENDING → APPROVED → DISPENSING → DISPENSED → TAKEN`, or `MISSED` / `SKIPPED` / `POSTPONED`. `DISPENSED` means the motor released the pills but the IR sensor hasn't confirmed the compartment is empty yet — `TAKEN` is set **only** by that IR confirmation, never by a successful motor move alone. There is currently no failure/timeout status for a stuck `DISPENSED` intake — see "Device Communication" below.

## Notification Flow

```
ReminderScheduler.sendReminder(timing)
  → creates Intake record
  → notificationPort.send("Time to take your {timing} medicines", intakeId, timing)
  → NotificationAdapter stores in static field
  → GET /api/notification drains it to frontend
  → POST /api/notification handles: snooze_15, snooze_custom:HH:MM, skip, or confirm
```

Scheduled cron times (currently set to demo/test times):
- MORNING → `0 05 22 * * *` (22:05)
- NOON    → `0 10 22 * * *` (22:10)
- EVENING → `0 30 22 * * *` (22:30)

Production times would be 08:00 / 13:00 / 20:00 — change cron expressions in `ReminderScheduler.java`.

## Device Communication

The pill box is never called directly by the app — it holds one persistent WebSocket connection to the backend (`/ws/device`), and the app talks to the device only through backend REST calls. The app remains the decision-maker (when to dispense, what to show); the backend is purely a relay + persistence layer + connection manager, never an autonomous orchestrator.

**Device → backend (WS, device-initiated):** connects to `wss://<host>/ws/device?deviceId=<key>&token=<secret>` on boot; `DeviceAuthHandshakeInterceptor` validates the token (SHA-256 against `devices.secret_hash`) before accepting the handshake. Messages: `heartbeat` (periodic, updates `last_seen_at`/marks `ONLINE`), `ack` (commandId receipt), `event: dispensed` (motor finished → `IntakeService.markDispensed`), `event: intake_confirmed` (IR sensor saw the compartment go empty → `IntakeService.markTaken`).

**Backend → device (same WS):** `command: dispense` with a generated `commandId`, sent by `DeviceConnectionAdapter.dispatchDispense`.

**App → backend:** `POST /api/intakes/{id}/dispense` — requires the intake to be `APPROVED`; looks up the patient's `Device`, sends the WS command, and blocks briefly (~5s) for the ack. Returns `409` if the device is offline or doesn't ack in time (intake stays `APPROVED` — no failure status is invented); on ack, intake moves to `DISPENSING`. `GET /api/devices/me/status` reports current `ONLINE`/`OFFLINE` + `last_seen_at`.

**Reliability, deliberately scoped:** the ack/retry above is transport-level only (did the command reach the device), not a business decision — retries never happen automatically after that point. `DeviceHeartbeatScheduler` sweeps every 30s and flips a device to `OFFLINE` if no heartbeat/message arrived in 90s. There is intentionally **no** jam-detection/`DISPENSE_FAILED` status and **no** timeout that moves a `DISPENSED` intake to `MISSED` or anything else — an intake can sit at `DISPENSED` indefinitely until the IR event arrives, by design (no reliable jam detection exists yet).

## Auth

Every `/api/**` request requires `Authorization: Bearer <Firebase ID token>` — enforced by `AuthInterceptor` (`api/auth/`), which verifies the token via `FirebaseAuth` and, if a local `User` row exists for that `firebase_uid`, attaches it to the request as `CurrentUserContext`. Controllers call `authService.resolvePatientId(currentUserContext.getUser())` instead of hardcoding an id: a patient resolves to their own id, a caregiver resolves to the patient they're linked to via `caregiver_links` (`AuthService.resolvePatientId`). One patient per deployment; caregivers register by supplying that patient's email, verified server-side (`AuthService.register` looks it up via `UserRepositoryPort.findByEmail`, rejects with 404 if no matching registered patient), then auto-linked via `caregiver_links`. Scheduled/internal callers with no request context (`ReminderScheduler`, `NotificationAdapter`) resolve the patient via `UserRepositoryPort.findFirstByType(PATIENT)` instead.

## REST API

All endpoints under `/api/*` with `@CrossOrigin(origins = "*")`; all require the bearer token above except that `/api/auth/register` doesn't require a pre-existing local `User` (it creates one).

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | `{idToken, role, firstName, lastName, patientEmail?}` → claims/creates the local `User` for this Firebase account. `patientEmail` is required for `role=CAREGIVER` and must match an already-registered patient (404 if not found); a second claimed `role=PATIENT` signup is rejected (409) |
| GET | `/api/auth/me` | Returns the resolved `User` for the current token, or 404 if not registered yet |
| GET | `/api/notification` | Poll for pending notification |
| POST | `/api/notification` | Send user response (confirm/snooze/skip) |
| GET | `/api/medications` | List all medicines |
| POST | `/api/medications` | Register a new medicine |
| GET | `/api/intakes/today` | Today's intakes for the resolved patient |
| PATCH | `/api/intakes/{id}/approve` | User approved intake |
| POST | `/api/intakes/{id}/dispense` | Relays a dispense command to the patient's device over WS; intake → DISPENSING on ack, `409` if device unreachable |
| PATCH | `/api/intakes/{id}/skip` | User skipped intake |
| PATCH | `/api/intakes/{id}/postpone` | User postponed intake |
| PATCH | `/api/intakes/{id}/missed` | Mark intake as MISSED |
| GET | `/api/notifications-log` | Notification history (query param: userId) |
| PUT | `/api/users/me/fcm-token` | Sets the FCM token for the authenticated user (no id param — inferred from the token) |
| GET | `/api/devices/me/status` | Online/offline status + last-seen timestamp for the resolved patient's device |

`/ws/device` (not under `/api/**`) is the device's WebSocket relay endpoint — authenticated separately via `deviceId`/`token` query params, not the Firebase bearer token above. See "Device Communication".

## Database

PostgreSQL 15 via Docker (`medify` db, `medify_user`/`medify_pass`, port 5432). Schema managed by Flyway (`ddl-auto=validate`). Key tables: `medications`, `users` (has `type` PATIENT/CAREGIVER and a unique nullable `firebase_uid`, claimed on registration), `intakes` (now also `device_id` FK), `caregiver_links`, `notification_logs`, `devices` (`device_key` unique, `user_id` FK, `secret_hash`, `status`, `last_seen_at`). V15 seeds one demo device (`device_key='pillbox-01'`) bound to the seeded patient — see that migration's comment for the matching dev token to flash into the Arduino.

## Tech

- Java 21, Spring Boot 3.4.0
- Lombok (`@Data`, `@NoArgsConstructor`, `@AllArgsConstructor`) on all domain models
- Firebase Admin SDK (`firebase-admin`, already used for FCM push) also backs auth — `FirebaseConfig` exposes a `FirebaseAuth` bean used by `AuthInterceptor`/`AuthService` to verify ID tokens
- `spring-boot-starter-websocket` backs the device relay (`WebSocketConfig`, `/ws/device`)
- One-patient-plus-caregiver(s)-per-deployment model, not full multi-tenancy — see "Auth" above
