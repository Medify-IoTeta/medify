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
├── main.dart                   # home: AuthGate
├── screens/
│   ├── auth_gate.dart          # App root — routes signed-out/mid-registration/patient/caregiver
│   ├── auth_screen.dart        # Firebase email/password login + signup
│   ├── complete_registration_screen.dart  # One-time role (Patient/Caregiver) + name picker
│   ├── home_screen.dart       # Patient main screen — schedule + polling
│   ├── caregiver_screen.dart  # Caregiver view — schedule + intake status + alerts (takes userId)
│   └── register_screen.dart  # Add a new medicine
├── models/
│   └── medicine.dart          # Medicine, TimePeriod, DosageUnit, InstructionOption, MedicationStatus
├── services/
│   ├── api_service.dart       # All HTTP calls to backend (192.168.7.17:8080 for Android) — every call sends Authorization: Bearer <Firebase ID token>
│   └── auth_service.dart      # Thin wrapper over FirebaseAuth (signUp/signIn/signOut/idToken)
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
`HomeScreen` polls `GET /api/notification` every 3 seconds. The response now carries an explicit `type` field:
- `type: "BUTTON_PRESSED"` — the pill box's physical button was pressed. The backend deliberately doesn't pick an intake for this (see backend `CLAUDE.md` "Physical button"); `_handleButtonPressed()` calls `getTodayIntakes()`, finds the first `PENDING` one itself, and opens the same reminder dialog as if it came from a normal reminder. If nothing is pending, shows a snackbar instead.
- Any other type (`WINDOW_REMINDER` etc.) — shows the reminder dialog as before:
  - "Show medicines ▼" / "Hide medicines" toggle expands to list medicines in that window with dosage
  - Actions: Choose Time (snooze to specific time → postponeIntake + snooze_custom:HH:MM), Remind in 15 min (postponeIntake + snooze_15), OK (confirm)

**On confirm (`_handleConfirmIntake`):** approveIntake → `dispenseIntake` (relays a dispense command to the device through the backend's WebSocket connection — the app never talks to the device directly) → poll `getIntake(id)` every 3s for up to ~2 minutes waiting for `TAKEN`. Medicines in the confirmed timing window move through local `MedicationStatus` states as this happens: `dispensing` (right after the dispense call) → `dispensed` (if the poll gives up before the IR sensor confirms — this is a normal, expected stopping point, not an error) → `taken` (once the backend reports `TAKEN`). A `409` from `dispenseIntake` (e.g. device offline) reverts the window back to `pending` and shows the backend's actual error message.

### Sidebar (AppSidebar)
Items: **Home**, **Add Medicine** (patient only), **Edit Medicines** (patient only), **Fill Pill Box** (both roles), **Log Out**.
Props: `onAddMedicine`, `onEditMedicines`, `onFillBox` — each item only renders if its callback is non-null, so `HomeScreen` passes all three and `CaregiverScreen` passes only `onFillBox`. Log Out calls `AuthService().signOut()`; `AuthGate`'s `authStateChanges` listener routes back to `AuthScreen` automatically.

### Caregiver Screen
Takes `required int userId` (the caregiver's real backend id, resolved by `AuthGate` from `GET /api/auth/me`). Loads in parallel: `getTodayIntakes()`, `getMedicines()`, `getNotificationsLog(widget.userId)`. Has its own drawer (`AppSidebar(onFillBox: ...)`) so a caregiver can reach Fill Pill Box directly.
- **Summary card** — `taken / totalWindows` windows completed (total based on medicines, not intakes)
- **Medication Schedule** — always visible, grouped by window, expandable
- **Today's Intake Status** — intake records from backend, expandable per window
- **Alerts** (`_alerts`, was "Missed Alerts") — filtered from notification log where type is `MISSED_INTAKE` or `INCOMPLETE_INTAKE`; `_buildAlertCard` shows a distinct icon + "Missed"/"Incomplete" label chip per entry so the two are visually distinguishable, not just by message text

### Fill Pill Box cross-role sync
`fill_box_guide_screen.dart` polls `GET /api/box-refill/current` every 3 seconds while visible (same `Future.doWhile` pattern as the notification poll) so a fill made from one role's session shows up in the other's within a few seconds. Both patient and caregiver requests resolve to the same box-refill session server-side (backend resolves "the patient" from the caregiver's `CaregiverLink`), so no client-side merging is needed — just re-fetch and replace.

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
| `dispenseIntake(id)` | POST /api/intakes/{id}/dispense — relays to the device via the backend's WebSocket; throws `ApiException` with the backend's message (e.g. device offline) on failure |
| `getIntake(id)` | GET /api/intakes/{id} — used to poll status after dispensing |
| `skipIntake(id)` | PATCH /api/intakes/{id}/skip |
| `postponeIntake(id)` | PATCH /api/intakes/{id}/postpone |
| `getNotificationsLog(userId, {from, to})` | GET /api/notifications-log?userId={id}[&from=&to=] |
| `registerBackendUser(idToken, role, firstName, lastName, {patientEmail})` | POST /api/auth/register — claims/creates the local `User` row for a Firebase account. `patientEmail` required for `role: 'CAREGIVER'` |
| `getCurrentBackendUser()` | GET /api/auth/me — 404 → `null` (not registered yet) |
| `registerFcmToken(token)` | PUT /api/users/me/fcm-token — identity comes from the auth header, no userId param |

There is no device-facing base URL anymore — every call goes to the backend, which relays to the device over its own WebSocket connection. Every method above sends `Authorization: Bearer <idToken>` via a shared `_authHeaders()` helper, using `AuthService().idToken()`.

## Models

`TimePeriod`: `morning`, `noon`, `evening` — `.name.toUpperCase()` to match backend `Timing` enum.

`MedicationStatus`: `pending`, `dispensing`, `dispensed`, `taken`, `missed`, `incomplete` — `dispensing`/`dispensed`/`incomplete` are local-only reflections of the backend's `DISPENSING`/`DISPENSED`/`INCOMPLETE` intake states (mapped in `home_screen.dart`'s `_mapIntakeStatus`). `incomplete` means the backend's `MissedIntakeScheduler` swept a `DISPENSED` intake whose IR-confirmation grace period expired — set entirely server-side, the app just displays it.

`InstructionOption`: `afterFood`, `emptyStomach`, `other`

## Auth

Firebase Authentication (email/password). `AuthGate` (app root) listens to `authStateChanges`; signed out → `AuthScreen`; signed in but no local backend `User` yet → `CompleteRegistrationScreen` (role, first/last name, and — if role is Caregiver — the patient's email, calls `registerBackendUser`); signed in + registered → `HomeScreen` (type `PATIENT`) or `CaregiverScreen(userId: ...)` (type `CAREGIVER`), resolved from `GET /api/auth/me`. One patient per pillbox; a caregiver must enter that exact patient's email to register (backend verifies it exists — 404 if not, 409 if a second patient tries to register) and is then auto-linked via `caregiver_links`.

## Notes

- The original React prototype is at `../lovable-project` — use as visual reference only
