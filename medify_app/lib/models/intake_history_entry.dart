import 'medicine.dart';

/// Mirrors the backend's IntakeHistoryEntry.Outcome — the single computed classification of
/// "what happened to this dose," shared by both the patient app and the caregiver view so they
/// never disagree.
enum IntakeOutcome {
  takenOnTime,
  takenAfterPostponed,
  takenAfterMissed,
  missed,
  skipped,
  incomplete,
  pending,
  approved,
  postponed,
  dispensing,
  dispensed;

  static IntakeOutcome fromApi(String? value) {
    switch (value) {
      case 'TAKEN_ON_TIME':        return IntakeOutcome.takenOnTime;
      case 'TAKEN_AFTER_POSTPONED': return IntakeOutcome.takenAfterPostponed;
      case 'TAKEN_AFTER_MISSED':   return IntakeOutcome.takenAfterMissed;
      case 'MISSED':               return IntakeOutcome.missed;
      case 'SKIPPED':              return IntakeOutcome.skipped;
      case 'INCOMPLETE':           return IntakeOutcome.incomplete;
      case 'PENDING':               return IntakeOutcome.pending;
      case 'APPROVED':             return IntakeOutcome.approved;
      case 'POSTPONED':            return IntakeOutcome.postponed;
      case 'DISPENSING':           return IntakeOutcome.dispensing;
      case 'DISPENSED':            return IntakeOutcome.dispensed;
      default:                     return IntakeOutcome.pending;
    }
  }
}

/// One row of intake history, as returned by GET /api/intakes/history. `scheduledDate` isn't
/// parsed separately — the backend serializes a LocalDate as a 3-element array, which
/// [parseBackendDateTime] doesn't handle (it expects a 5+ element LocalDateTime array), so the
/// day for grouping is derived from [scheduledTime] instead.
class IntakeHistoryEntry {
  final int intakeId;
  final String timing; // MORNING / NOON / EVENING
  final DateTime scheduledTime;
  final String status; // raw backend IntakeStatus, for anything not covered by outcome
  final IntakeOutcome outcome;
  final DateTime? takenAt;
  final int? latenessMinutes;
  final bool wasPostponed;

  IntakeHistoryEntry({
    required this.intakeId,
    required this.timing,
    required this.scheduledTime,
    required this.status,
    required this.outcome,
    this.takenAt,
    this.latenessMinutes,
    this.wasPostponed = false,
  });

  factory IntakeHistoryEntry.fromJson(Map<String, dynamic> json) {
    return IntakeHistoryEntry(
      intakeId: json['intakeId'] as int,
      timing: (json['timing'] as String).toUpperCase(),
      scheduledTime: parseBackendDateTime(json['scheduledTime'])!,
      status: json['status'] as String,
      outcome: IntakeOutcome.fromApi(json['outcome'] as String?),
      takenAt: parseBackendDateTime(json['takenAt']),
      latenessMinutes: json['latenessMinutes'] as int?,
      wasPostponed: json['wasPostponed'] as bool? ?? false,
    );
  }
}
