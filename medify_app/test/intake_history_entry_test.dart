// Model-level tests for parsing the backend's GET /api/intakes/history response.
// Deliberately avoids pumping a widget tree or touching Firebase, same rationale as
// medicine_status_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:medify_app/models/intake_history_entry.dart';

void main() {
  group('IntakeHistoryEntry.fromJson', () {
    Map<String, dynamic> baseJson({
      String outcome = 'TAKEN_ON_TIME',
      dynamic takenAt,
      int? latenessMinutes,
      bool wasPostponed = false,
    }) =>
        {
          'intakeId': 1,
          'timing': 'MORNING',
          'scheduledDate': [2026, 9, 1],
          'scheduledTime': [2026, 9, 1, 8, 0],
          'status': 'TAKEN',
          'outcome': outcome,
          'takenAt': takenAt,
          'latenessMinutes': latenessMinutes,
          'wasPostponed': wasPostponed,
        };

    test('parses a taken-on-time entry', () {
      final entry = IntakeHistoryEntry.fromJson(
        baseJson(takenAt: [2026, 9, 1, 8, 5], latenessMinutes: 5),
      );

      expect(entry.intakeId, 1);
      expect(entry.timing, 'MORNING');
      expect(entry.outcome, IntakeOutcome.takenOnTime);
      expect(entry.takenAt, DateTime(2026, 9, 1, 8, 5));
      expect(entry.latenessMinutes, 5);
      expect(entry.wasPostponed, false);
    });

    test('parses a missed entry with no takenAt/lateness', () {
      final entry = IntakeHistoryEntry.fromJson(baseJson(outcome: 'MISSED'));

      expect(entry.outcome, IntakeOutcome.missed);
      expect(entry.takenAt, isNull);
      expect(entry.latenessMinutes, isNull);
    });

    test('parses taken-after-missed with a wasPostponed flag preserved', () {
      final entry = IntakeHistoryEntry.fromJson(baseJson(
        outcome: 'TAKEN_AFTER_MISSED',
        takenAt: [2026, 9, 1, 10, 0],
        latenessMinutes: 120,
        wasPostponed: true,
      ));

      expect(entry.outcome, IntakeOutcome.takenAfterMissed);
      expect(entry.latenessMinutes, 120);
      expect(entry.wasPostponed, true);
    });

    test('unknown outcome falls back to pending rather than throwing', () {
      final entry = IntakeHistoryEntry.fromJson(baseJson(outcome: 'SOMETHING_NEW'));
      expect(entry.outcome, IntakeOutcome.pending);
    });

    test('every non-taken IntakeStatus keeps a distinct outcome', () {
      expect(IntakeOutcome.fromApi('SKIPPED'), IntakeOutcome.skipped);
      expect(IntakeOutcome.fromApi('INCOMPLETE'), IntakeOutcome.incomplete);
      expect(IntakeOutcome.fromApi('DISPENSING'), IntakeOutcome.dispensing);
      expect(IntakeOutcome.fromApi('DISPENSED'), IntakeOutcome.dispensed);
      expect(IntakeOutcome.fromApi('POSTPONED'), IntakeOutcome.postponed);
      expect(IntakeOutcome.fromApi('PENDING'), IntakeOutcome.pending);
      expect(IntakeOutcome.fromApi('APPROVED'), IntakeOutcome.approved);
    });
  });
}
