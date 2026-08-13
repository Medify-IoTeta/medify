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

- **domain** — Pure business logic. Models: `Medicine`, `Timing`, `Intake`, `IntakeStatus`, `User`, `CaregiverLink`, `NotificationLog`. Port interfaces: `MedicineRepositoryPort`, `IntakeRepositoryPort`, `NotificationPort`, etc. Schedulers: `ReminderScheduler`, `MissedIntakeScheduler`.
- **data** — JPA/Flyway persistence. Each `*Repository` implements its domain port. Migrations in `data/src/main/resources/db/migration/`.
- **api** — REST controllers, services, and `NotificationAdapter` (implements `NotificationPort` via static in-memory queue).
- **app** — Spring Boot entry point only.

## Key Domain Rules

- One `Intake` record is created **per timing window** (not per medicine) when the scheduler fires
- `NotificationPort.send(message, intakeId, timing)` — `timing` is the window name (MORNING/NOON/EVENING), always included so the frontend knows which window to confirm
- Intake status flow: `PENDING → APPROVED → TAKEN` (device confirms compartment emptied) or `MISSED` / `SKIPPED` / `POSTPONED`

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

## Auth

Every `/api/**` request requires `Authorization: Bearer <Firebase ID token>` — enforced by `AuthInterceptor` (`api/auth/`), which verifies the token via `FirebaseAuth` and, if a local `User` row exists for that `firebase_uid`, attaches it to the request as `CurrentUserContext`. Controllers call `authService.resolvePatientId(currentUserContext.getUser())` instead of hardcoding an id: a patient resolves to their own id, a caregiver resolves to the patient they're linked to via `caregiver_links` (`AuthService.resolvePatientId`). One patient per deployment; any number of caregivers, auto-linked to the patient at registration time (`AuthService.register`). Scheduled/internal callers with no request context (`ReminderScheduler`, `NotificationAdapter`) resolve the patient via `UserRepositoryPort.findFirstByType(PATIENT)` instead.

## REST API

All endpoints under `/api/*` with `@CrossOrigin(origins = "*")`; all require the bearer token above except that `/api/auth/register` doesn't require a pre-existing local `User` (it creates one).

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | `{idToken, role, username}` → claims/creates the local `User` for this Firebase account |
| GET | `/api/auth/me` | Returns the resolved `User` for the current token, or 404 if not registered yet |
| GET | `/api/notification` | Poll for pending notification |
| POST | `/api/notification` | Send user response (confirm/snooze/skip) |
| GET | `/api/medications` | List all medicines |
| POST | `/api/medications` | Register a new medicine |
| GET | `/api/intakes/today` | Today's intakes for the resolved patient |
| PATCH | `/api/intakes/{id}/approve` | User approved intake |
| PATCH | `/api/intakes/{id}/released` | Device confirmed compartment emptied → TAKEN |
| PATCH | `/api/intakes/{id}/skip` | User skipped intake |
| PATCH | `/api/intakes/{id}/postpone` | User postponed intake |
| PATCH | `/api/intakes/{id}/missed` | Mark intake as MISSED |
| GET | `/api/notifications-log` | Notification history (query param: userId) |
| PUT | `/api/users/me/fcm-token` | Sets the FCM token for the authenticated user (no id param — inferred from the token) |

## Database

PostgreSQL 15 via Docker (`medify` db, `medify_user`/`medify_pass`, port 5432). Schema managed by Flyway (`ddl-auto=validate`). Key tables: `medications`, `users` (has `type` PATIENT/CAREGIVER and a unique nullable `firebase_uid`, claimed on registration), `intakes`, `caregiver_links`, `notification_logs`.

## Tech

- Java 21, Spring Boot 3.4.0
- Lombok (`@Data`, `@NoArgsConstructor`, `@AllArgsConstructor`) on all domain models
- Firebase Admin SDK (`firebase-admin`, already used for FCM push) also backs auth — `FirebaseConfig` exposes a `FirebaseAuth` bean used by `AuthInterceptor`/`AuthService` to verify ID tokens
- One-patient-plus-caregiver(s)-per-deployment model, not full multi-tenancy — see "Auth" above
