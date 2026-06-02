# Medify — Project CLAUDE.md

## What is Medify

A smart medication intake system. A physical pill box (Arduino/C++) releases medication at scheduled times. A Flutter mobile app handles reminders, intake confirmation, and caregiver monitoring. A Spring Boot backend coordinates everything.

## Repo Structure

```
medify/
├── medify-backend/   # Java Spring Boot backend (hexagonal architecture)
├── medify_app/       # Flutter mobile app (patient + caregiver)
├── docs/             # project-overview.docx — product requirements
└── lovable-project/  # Original React/TypeScript prototype (reference only)
```

## System Architecture

```
Smart Pill Box (Arduino/C++) ──WiFi──► Backend (Spring Boot)
Mobile App (Flutter)         ──REST──► Backend (Spring Boot)
                                              │
                                        PostgreSQL 15
```

## Core Domain Concepts

- **Timing** — Three intake windows per day: `MORNING`, `NOON`, `EVENING` (currently scheduled at 22:05/22:10/22:30 for demo — production times are 08:00/13:00/20:00)
- **Medicine** — A prescribed medication assigned to one timing window, with dosage and instructions
- **Intake** — One record per timing window per day; tracks status: `PENDING → APPROVED → TAKEN` (or `MISSED`, `SKIPPED`, `POSTPONED`)
- **Notification** — Backend queues one notification per timing window; frontend polls and shows a dialog

## Notification Flow

1. `ReminderScheduler` fires at scheduled time → creates one `Intake` record → calls `NotificationPort.send(message, intakeId, timing)`
2. `NotificationAdapter` stores it in a static field
3. Flutter polls `GET /api/notification` every 3 seconds
4. User confirms → `approveIntake` → device dispenses → `releaseIntake` → marks intake as TAKEN
5. Flutter updates local state for **only** the medicines in the confirmed timing window

## Running Locally

```bash
# 1. Start the database
cd medify-backend && docker-compose up -d

# 2. Start the backend
mvn spring-boot:run -pl app

# 3. Start the Flutter app
cd medify_app && flutter run
```

## Sub-module Docs

- Backend details: `medify-backend/CLAUDE.md`
- Flutter details: `medify_app/CLAUDE.md`
