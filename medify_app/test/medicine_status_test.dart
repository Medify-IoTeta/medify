// Model-level tests for how backend intake statuses map onto Medicine/MedicationStatus.
// Deliberately avoids pumping a widget tree or touching Firebase (AuthGate initializes
// FirebaseAuth on construction, which isn't available in a plain `flutter test` run without
// additional setup) — these are the statuses this refactor actually changes, tested directly.

import 'package:flutter_test/flutter_test.dart';
import 'package:medify_app/models/medicine.dart';

void main() {
  group('Medicine.fromJson status parsing', () {
    Map<String, dynamic> baseJson(String status) => {
          'id': 1,
          'name': 'Aspirin',
          'timing': 'MORNING',
          'status': status,
          'dosageUnit': 'pills',
        };

    test('parses postponed status from the backend', () {
      final medicine = Medicine.fromJson(baseJson('postponed'));
      expect(medicine.status, MedicationStatus.postponed);
    });

    test('parses missed status from the backend', () {
      final medicine = Medicine.fromJson(baseJson('missed'));
      expect(medicine.status, MedicationStatus.missed);
    });

    test('unknown status falls back to pending rather than throwing', () {
      final medicine = Medicine.fromJson(baseJson('approved'));
      expect(medicine.status, MedicationStatus.pending);
    });

    test('round-trips through toJson', () {
      final medicine = Medicine.fromJson(baseJson('postponed'));
      expect(medicine.toJson()['status'], 'postponed');
    });
  });

  group('MedicationStatus enum', () {
    test('includes postponed alongside the existing backend-derived statuses', () {
      expect(MedicationStatus.values, contains(MedicationStatus.postponed));
      expect(MedicationStatus.values, contains(MedicationStatus.missed));
      expect(MedicationStatus.values, contains(MedicationStatus.dispensing));
      expect(MedicationStatus.values, contains(MedicationStatus.dispensed));
      expect(MedicationStatus.values, contains(MedicationStatus.incomplete));
    });
  });
}
