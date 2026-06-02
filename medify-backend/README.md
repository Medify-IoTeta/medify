# Medify Backend

Spring Boot backend server for the Medify smart pill box system. Handles medication schedules, intake tracking, notifications, and caregiver monitoring.

## Tech Stack

- Java 21
- Spring Boot 3.4.0
- PostgreSQL 15
- Flyway (database migrations)
- JPA / Hibernate
- Lombok
- Docker

## Architecture

Hexagonal (ports-and-adapters) Maven multi-module project:

```
app → api → domain
      ↓
     data → domain
```

| Module | Responsibility |
|--------|---------------|
| `domain` | Business logic, models, port interfaces, schedulers |
| `data` | JPA repositories, Flyway migrations |
| `api` | REST controllers, services, NotificationAdapter |
| `app` | Spring Boot entry point |

## Getting Started

### Prerequisites

- Java 21
- Maven
- Docker

### Run

```bash
# Start the database
docker-compose up -d

# Build and run
mvn spring-boot:run -pl app
```

The server starts on `http://localhost:8080`.

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/notification` | Poll for a pending notification |
| POST | `/api/notification` | Send user response (confirm / snooze / skip) |
| GET | `/api/medicines` | List all medicines |
| POST | `/api/medicines` | Register a new medicine |
| GET | `/api/intakes/today` | Today's intakes |
| PATCH | `/api/intakes/{id}/approve` | User approved intake |
| PATCH | `/api/intakes/{id}/released` | Device confirmed compartment emptied → TAKEN |
| PATCH | `/api/intakes/{id}/skip` | User skipped intake |
| PATCH | `/api/intakes/{id}/postpone` | User postponed intake |
| PATCH | `/api/intakes/{id}/missed` | Mark intake as MISSED |
| GET | `/api/notifications-log` | Notification history (`?userId=`) |

## Notification Flow

1. Scheduler fires at scheduled time (currently demo times: 22:05 / 22:10 / 22:30)
2. Creates one `Intake` record per timing window
3. Sends notification: `"Time to take your morning medicines"`
4. Frontend polls `GET /api/notification` and shows a dialog
5. User confirms → `approve` → device dispenses → `released` → intake marked as TAKEN

> To switch to production times (08:00 / 13:00 / 20:00), update the `@Scheduled` cron expressions in `ReminderScheduler.java`.

## Database

PostgreSQL 15 via Docker.

| Setting | Value |
|---------|-------|
| Database | `medify` |
| User | `medify_user` |
| Password | `medify_pass` |
| Port | `5432` |

Schema is managed by Flyway. Migrations are in `data/src/main/resources/db/migration/`.
