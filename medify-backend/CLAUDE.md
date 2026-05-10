# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Start the database (required before running the app)
docker-compose up -d

# Build all modules
mvn clean install

# Run the application
mvn spring-boot:run -pl app

# Run all tests
mvn test

# Run tests for a single module
mvn test -pl api -Dtest=SomeControllerTest

# Run a single test method
mvn test -pl domain -Dtest=ClassName#methodName
```

## Architecture

This is a **hexagonal (ports-and-adapters)** Maven multi-module project. The dependency direction is:

```
app → api → domain
      ↓
     data → domain
```

- **domain** — Pure business logic: `Medicine`/`Timing` models, port interfaces (`MedicineRepositoryPort`, `NotificationPort`), and `ReminderScheduler` (Spring `@Scheduled` cron jobs at 08:00, 13:00, 20:00).
- **data** — JPA/Flyway persistence. `MedicineRepository` implements `MedicineRepositoryPort`. Migrations live in `data/src/main/resources/db/migration/`.
- **api** — REST controllers, `MedicineService`, and `NotificationAdapter` (implements `NotificationPort` with a static in-memory queue).
- **app** — Spring Boot entry point only; aggregates all other modules.

### Notification flow

The frontend polls `GET /api/notification` to receive pending messages. `ReminderScheduler` calls `NotificationPort.send()`, which stores the message in `NotificationAdapter`'s static field. `NotificationController.getNotification()` drains it on each poll. `POST /api/notification` handles user responses (confirm intake, snooze).

### Database

PostgreSQL 15 via Docker (`medify` db, `medify_user`/`medify_pass`, port 5432). Schema is managed by Flyway (`spring.jpa.hibernate.ddl-auto=validate`). The `medications` table has a `user_id` column whose foreign key constraint is currently commented out pending a `users` table.

### Key tech

- Java 21, Spring Boot 3.4.0
- Lombok (`@Data`, `@NoArgsConstructor`, `@AllArgsConstructor`) on domain models
- All REST endpoints under `/api/*` with `@CrossOrigin(origins = "*")`