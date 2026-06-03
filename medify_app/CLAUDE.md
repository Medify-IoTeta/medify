# Medify Flutter App — CLAUDE.md

## Commands

```bash
flutter run          # Run on connected device/emulator
flutter build apk    # Build Android APK
flutter analyze      # Static analysis
flutter test         # Run tests
```

## Project Structure

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart       # Patient main screen — schedule + polling
│   ├── caregiver_screen.dart  # Caregiver view — schedule + intake status + alerts
│   └── register_screen.dart  # Add a new medicine
├── models/
│   └── medicine.dart          # Medicine, TimePeriod, DosageUnit, InstructionOption, MedicationStatus
├── services/
│   └── api_service.dart       # All HTTP calls to backend (192.168.7.17:8080 for Android)
├── widgets/
│   ├── medication_card.dart   # Single medicine card with status badge
│   ├── app_sidebar.dart       # Navigation drawer
│   └── progress_ring.dart     # Circular progress indicator
└── theme/
    └── app_theme.dart         # AppColors, AppTextStyles, AppSpacing, AppRadius
```

## Key UI Patterns

### Schedule Display (both screens)
Medicines are grouped by timing window (MORNING / NOON / EVENING) using `ExpansionTile`. Each group shows the window name, icon, and a count. Expanding reveals individual medicines with dosage and instructions.

### Home Screen Progress
- `_totalWindows` — number of timing windows that have at least one medicine
- `_completedWindows` — windows where **all** medicines are status `taken`
- Displayed in `ProgressRing` and subtitle ("X windows remaining")
- On init: loads medicines + today's intakes in parallel; medicines whose timing window is TAKEN are marked `taken` in local state

### Notification Polling
`HomeScreen` polls `GET /api/notification` every 3 seconds. On response:
- Shows a dialog with the timing window name
- "Show medicines ▼" / "Hide medicines" toggle expands to list medicines in that window with dosage
- Actions: Choose Time (snooze to specific time → postponeIntake + snooze_custom:HH:MM), Remind in 15 min (postponeIntake + snooze_15), OK (confirm)
- On confirm: approveIntake → dispenseFromDevice → releaseIntake → marks only medicines in the confirmed timing window as `taken` in local state

### Sidebar (AppSidebar)
Items: **Home**, **Add Medicine**, **Edit Medicines**, **Caregiver View**.
Props: `onAddMedicine`, `onEditMedicines` (both optional callbacks).
"Take Medication Manually" was removed.

### Caregiver Screen
Loads in parallel: `getTodayIntakes()`, `getMedicines()`, `getNotificationsLog(_caregiverUserId)`.
- **Summary card** — `taken / totalWindows` windows completed (total based on medicines, not intakes)
- **Medication Schedule** — always visible, grouped by window, expandable
- **Today's Intake Status** — intake records from backend, expandable per window
- **Missed Alerts** — filtered from notification log where type == MISSED_INTAKE

## API Calls (api_service.dart)

Base URLs:
- `http://192.168.7.17:8080` — Android device (active)
- `http://localhost:8080` — browser/emulator (commented out in code)
- `http://192.168.7.18` — embedded pill box device

| Method | Description |
|--------|-------------|
| `getMedicines()` | GET /api/medications |
| `registerMedicine(medicine)` | POST /api/medications |
| `getNotification()` | GET /api/notification — returns `{status, message, intakeId, timing}` |
| `sendNotification(message, intakeId)` | POST /api/notification |
| `getTodayIntakes()` | GET /api/intakes/today |
| `approveIntake(id)` | PATCH /api/intakes/{id}/approve |
| `releaseIntake(id)` | PATCH /api/intakes/{id}/released |
| `skipIntake(id)` | PATCH /api/intakes/{id}/skip |
| `postponeIntake(id)` | PATCH /api/intakes/{id}/postpone |
| `getNotificationsLog(userId, {from, to})` | GET /api/notifications-log?userId={id}[&from=&to=] |
| `dispenseFromDevice()` | GET http://192.168.7.18/move — 15s timeout, handles JSON or plain-text "OK" |

## Models

`TimePeriod`: `morning`, `noon`, `evening` — `.name.toUpperCase()` to match backend `Timing` enum.

`MedicationStatus`: `pending`, `taken`, `missed`

`InstructionOption`: `afterFood`, `emptyStomach`, `other`

## Notes

- userId is hardcoded to `1` for the patient, `2` for the caregiver (`_caregiverUserId`)
- The original React prototype is at `../lovable-project` — use as visual reference only
