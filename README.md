# Medify — Smart Pill Box System

Medify is a smart medication intake system designed to help users manage and monitor their daily medication schedule. A physical smart pill box releases medication at scheduled times, while a mobile app handles reminders, intake confirmation, and caregiver monitoring.

## System Overview

```
Smart Pill Box (Arduino) ──WiFi──► Backend (Spring Boot) ◄──REST──  Mobile App (Flutter)
                                          │
                                    PostgreSQL 15
```

### Components

| Component | Technology | Location |
|-----------|-----------|----------|
| Mobile App | Flutter / Dart | `medify_app/` |
| Backend Server | Java 21 / Spring Boot 3.4 | `medify-backend/` |
| Smart Pill Box | C++ / Arduino | `medify-embedded/` |
| Documentation | | `docs/` |

## Key Features

- **Scheduled reminders** — notifications sent at Morning / Noon / Evening intake windows
- **Intake confirmation** — user approves via app, device physically releases medication
- **Intake tracking** — statuses: Pending, Approved, Taken, Missed, Skipped, Postponed
- **Caregiver monitoring** — family members can view intake history and receive missed-dose alerts
- **Simple UI** — designed for elderly and passive users

## Getting Started

### Prerequisites

- Java 21
- Maven
- Docker (for the database)
- Flutter SDK

### Run Locally

```bash
# 1. Start the database
cd medify-backend
docker-compose up -d

# 2. Start the backend
mvn spring-boot:run -pl app

# 3. Start the Flutter app (in a separate terminal)
cd medify_app
flutter run
```

## Documentation

- Backend: [`medify-backend/README.md`](medify-backend/README.md)
- Mobile App: [`medify_app/README.md`](medify_app/README.md)
- Product requirements: [`docs/project-overview.docx`](docs/project-overview.docx)
