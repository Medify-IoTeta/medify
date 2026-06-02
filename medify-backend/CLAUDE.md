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

## REST API

All endpoints under `/api/*` with `@CrossOrigin(origins = "*")`.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/notification` | Poll for pending notification |
| POST | `/api/notification` | Send user response (confirm/snooze/skip) |
| GET | `/api/medications` | List all medicines |
| POST | `/api/medications` | Register a new medicine |
| GET | `/api/intakes/today` | Today's intakes for userId=1 |
| PATCH | `/api/intakes/{id}/approve` | User approved intake |
| PATCH | `/api/intakes/{id}/released` | Device confirmed compartment emptied → TAKEN |
| PATCH | `/api/intakes/{id}/skip` | User skipped intake |
| PATCH | `/api/intakes/{id}/postpone` | User postponed intake |
| PATCH | `/api/intakes/{id}/missed` | Mark intake as MISSED |
| GET | `/api/notifications-log` | Notification history (query param: userId) |

## Database

PostgreSQL 15 via Docker (`medify` db, `medify_user`/`medify_pass`, port 5432). Schema managed by Flyway (`ddl-auto=validate`). Key tables: `medications`, `users`, `intakes`, `caregiver_links`, `notification_logs`.

## Tech

- Java 21, Spring Boot 3.4.0
- Lombok (`@Data`, `@NoArgsConstructor`, `@AllArgsConstructor`) on all domain models
- userId is hardcoded to `1L` throughout — multi-user support not yet implemented
