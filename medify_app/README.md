# Medify App

Flutter mobile application for the Medify smart pill box system. Serves both patients and caregivers.

## Tech Stack

- Flutter / Dart
- HTTP client (`package:http`)
- Google Fonts
- UUID

## Getting Started

### Prerequisites

- Flutter SDK
- Backend server running on `localhost:8080` (see [`medify-backend`](../medify-backend/README.md))

### Run

```bash
flutter run
```

## Screens

### Home Screen (Patient)
- Medication schedule grouped by intake window: Morning / Noon / Evening
- Each window is expandable to show medicines with dosage and instructions
- Progress indicator: how many windows completed today
- Notification polling every 3 seconds — shows a reminder dialog when it's time to take medication
- Dialog includes option to expand and see which medicines are in the window

### Caregiver Screen
- Summary card: windows completed today out of total scheduled
- Full medication schedule (always visible, grouped by window)
- Today's intake status per window (TAKEN / MISSED / PENDING / POSTPONED)
- Missed alerts log

### Register Screen
- Add a new medicine with name, dosage, timing window, and intake instructions

## Project Structure

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart
│   ├── caregiver_screen.dart
│   └── register_screen.dart
├── models/
│   └── medicine.dart
├── services/
│   └── api_service.dart
├── widgets/
│   ├── medication_card.dart
│   ├── app_sidebar.dart
│   └── progress_ring.dart
└── theme/
    └── app_theme.dart
```

## Configuration

Backend URL is set in `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'http://localhost:8080';
static const String embeddedBaseUrl = 'http://192.168.7.18'; // pill box device
```
