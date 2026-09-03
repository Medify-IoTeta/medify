import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/intake_history_entry.dart';
import '../models/medicine.dart';
import 'auth_service.dart';

/// Carries the backend's actual error message (not just the HTTP status),
/// so callers can show the real reason instead of guessing from a status code.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

Never _throwApiException(http.Response response) {
  String message = 'Request failed (${response.statusCode})';
  try {
    final body = jsonDecode(response.body);
    if (body is Map && body['message'] is String) message = body['message'];
  } catch (_) {
    // non-JSON body — keep the generic message
  }
  throw ApiException(response.statusCode, message);
}

class ApiService {
  // Override at build time: flutter run --dart-define=API_BASE_URL=http://<alb-dns-name>
  // Defaults to the LAN dev backend (Android over WiFi) when not overridden.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://172.20.10.2:8080',
  );

  final AuthService _authService = AuthService();

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final token = await _authService.idToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Future<List<Medicine>> getMedicines() async {
    final url = Uri.parse('$baseUrl/api/medications');
    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Medicine.fromJson(json)).toList();
    }

    throw Exception('Failed to load medicines: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> registerMedicine(Medicine medicine) async {
    final url = Uri.parse('$baseUrl/api/medications');

    final response = await http.post(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'userId': 1,
        'name': medicine.name,
        'timing': medicine.timePeriod.name.toUpperCase(),
        'description': medicine.instructionOption == InstructionOption.other
            ? medicine.instructions
            : medicine.instructionOption == InstructionOption.none
                ? null
                : medicine.instructionOption.name,
        'dosageAmount': medicine.dosageAmount,
        'dosageUnit': medicine.dosageUnit.name,
        'active': medicine.enabled,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to register medicine: ${response.statusCode}');
  }

  // ── Auth ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerBackendUser(
    String idToken,
    String role,
    String firstName,
    String lastName, {
    String? patientEmail,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/register');
    final response = await http.post(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'idToken': idToken,
        'role': role,
        'firstName': firstName,
        'lastName': lastName,
        if (patientEmail != null) 'patientEmail': patientEmail,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    _throwApiException(response);
  }

  Future<Map<String, dynamic>?> getCurrentBackendUser() async {
    final url = Uri.parse('$baseUrl/api/auth/me');
    final response = await http.get(url, headers: await _authHeaders());
    if (response.statusCode == 404) return null;
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get current user: ${response.statusCode}');
  }

  // ── Notifications ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getNotification() async {
    final url = Uri.parse('$baseUrl/api/notification');
    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to get notification: ${response.statusCode}');
  }

  // DEMO-ONLY: remove after exhibition — resets today's intake for this
  // timing back to PENDING; does NOT send a reminder notification.
  Future<void> resetDemoIntake(String timing) async {
    final url = Uri.parse('$baseUrl/api/notification/test')
        .replace(queryParameters: {'timing': timing});
    final response = await http.post(url, headers: await _authHeaders());
    if (response.statusCode != 200) _throwApiException(response);
  }

  Future<void> sendNotification(String message, {int? intakeId}) async {
    final url = Uri.parse('$baseUrl/api/notification');

    final response = await http.post(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'message': message,
        if (intakeId != null) 'intakeId': intakeId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send notification: ${response.statusCode}');
    }
  }

  // ── Intakes ───────────────────────────────────────────────────

  /// The one call behind starting/continuing an intake — the same shared backend logic the
  /// physical button uses. Pass [intakeId] to target a specific intake (e.g. "Take now" on a
  /// MISSED/POSTPONED card); omit it to act on whichever intake is earliest-and-eligible right
  /// now. Always returns 200 with a structured `outcome` — STARTED, or one of several blocked/
  /// unavailable outcomes with a `message` and (when relevant) a `blockingIntake` — never throws
  /// for a normal "not eligible right now" result, so callers should check `outcome` rather than
  /// wrapping this in a try/catch for business-logic branching.
  Future<Map<String, dynamic>> takeNow({int? intakeId}) async {
    final url = Uri.parse('$baseUrl/api/intakes/take-now');
    final response = await http.post(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({if (intakeId != null) 'intakeId': intakeId}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    _throwApiException(response);
  }

  Future<Map<String, dynamic>> approveIntake(int intakeId) async {
    final url = Uri.parse('$baseUrl/api/intakes/$intakeId/approve');
    final response = await http.patch(url, headers: await _authHeaders());

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to approve intake: ${response.statusCode}');
  }

  /// Relays a dispense command to the patient's pill box via the backend's
  /// WebSocket connection to the device. Throws ApiException with the
  /// backend's real message on failure (e.g. device offline) so the caller
  /// can show it directly instead of a generic error.
  Future<Map<String, dynamic>> dispenseIntake(int intakeId) async {
    final url = Uri.parse('$baseUrl/api/intakes/$intakeId/dispense');
    final response = await http.post(url, headers: await _authHeaders());
    if (response.statusCode == 200) return jsonDecode(response.body);
    _throwApiException(response);
  }

  /// Single-intake lookup, for polling status after a dispense
  /// (DISPENSING -> DISPENSED -> TAKEN, driven by the device's IR sensor).
  Future<Map<String, dynamic>?> getIntake(int intakeId) async {
    final url = Uri.parse('$baseUrl/api/intakes/$intakeId');
    final response = await http.get(url, headers: await _authHeaders());
    if (response.statusCode == 200) return jsonDecode(response.body);
    if (response.statusCode == 404) return null;
    throw Exception('Failed to get intake: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> skipIntake(int intakeId) async {
    final url = Uri.parse('$baseUrl/api/intakes/$intakeId/skip');
    final response = await http.patch(url, headers: await _authHeaders());

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to skip intake: ${response.statusCode}');
  }

  /// Flips the intake to POSTPONED and schedules its re-notification server-side, in one call —
  /// pass exactly one of [minutes] (relative snooze) or [until] ("HH:mm", absolute time); defaults
  /// to 15 minutes if neither is given.
  Future<Map<String, dynamic>> postponeIntake(int intakeId, {int? minutes, String? until}) async {
    final url = Uri.parse('$baseUrl/api/intakes/$intakeId/postpone');
    final response = await http.patch(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        if (until != null) 'until': until
        else 'minutes': minutes ?? 15,
      }),
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to postpone intake: ${response.statusCode}');
  }

  Future<List<Map<String, dynamic>>> getTodayIntakes() async {
    final url = Uri.parse('$baseUrl/api/intakes/today');
    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to get today intakes: ${response.statusCode}');
  }

  /// Same data for both the patient app and the caregiver view — the backend resolves the
  /// patient from whichever token calls this. Most recent first.
  Future<List<IntakeHistoryEntry>> getIntakeHistory({int days = 5}) async {
    final url = Uri.parse('$baseUrl/api/intakes/history')
        .replace(queryParameters: {'days': '$days'});
    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => IntakeHistoryEntry.fromJson(json)).toList();
    }

    throw Exception('Failed to get intake history: ${response.statusCode}');
  }

  // ── Medicine management ───────────────────────────────────────

  Future<Medicine> updateMedicine(
    String id, {
    required double dosageAmount,
    required String dosageUnit,
    required String timing,
    required bool active,
    DateTime? disabledUntil,
  }) async {
    final url = Uri.parse('$baseUrl/api/medications/$id');
    final response = await http.put(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'dosageAmount': dosageAmount,
        'dosageUnit': dosageUnit,
        'timing': timing,
        'active': active,
        if (disabledUntil != null)
          'disabledUntil': disabledUntil.toIso8601String().split('.').first,
      }),
    );
    if (response.statusCode == 200) return Medicine.fromJson(jsonDecode(response.body));
    throw Exception('Failed to update medicine: ${response.statusCode}');
  }

  Future<void> deleteMedicine(String id) async {
    final url = Uri.parse('$baseUrl/api/medications/$id');
    final response = await http.delete(url, headers: await _authHeaders());
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete medicine: ${response.statusCode}');
    }
  }

  Future<Medicine> disableMedicine(String id) async {
    final url = Uri.parse('$baseUrl/api/medications/$id/disable');
    final response = await http.patch(url, headers: await _authHeaders());
    if (response.statusCode == 200) return Medicine.fromJson(jsonDecode(response.body));
    throw Exception('Failed to disable medicine: ${response.statusCode}');
  }

  Future<Medicine> enableMedicine(String id) async {
    final url = Uri.parse('$baseUrl/api/medications/$id/enable');
    final response = await http.patch(url, headers: await _authHeaders());
    if (response.statusCode == 200) return Medicine.fromJson(jsonDecode(response.body));
    throw Exception('Failed to enable medicine: ${response.statusCode}');
  }

  Future<Medicine> disableMedicineUntil(String id, DateTime until) async {
    final url = Uri.parse('$baseUrl/api/medications/$id/disable-until');
    final response = await http.patch(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({'until': until.toIso8601String().split('.').first}),
    );
    if (response.statusCode == 200) return Medicine.fromJson(jsonDecode(response.body));
    throw Exception('Failed to disable medicine until: ${response.statusCode}');
  }

  Future<Medicine> clearDisabledUntil(String id) async {
    final url = Uri.parse('$baseUrl/api/medications/$id/clear-until');
    final response = await http.patch(url, headers: await _authHeaders());
    if (response.statusCode == 200) return Medicine.fromJson(jsonDecode(response.body));
    throw Exception('Failed to clear disabled-until: ${response.statusCode}');
  }

  // ── Caregiver ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotificationsLog(
    int userId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final params = {'userId': '$userId'};
    if (from != null) params['from'] = from.toIso8601String();
    if (to != null) params['to'] = to.toIso8601String();
    final url = Uri.parse('$baseUrl/api/notifications-log').replace(queryParameters: params);
    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to get notifications log: ${response.statusCode}');
  }

  // ── FCM Token ─────────────────────────────────────────────────

  Future<void> registerFcmToken(String token) async {
    final url = Uri.parse('$baseUrl/api/users/me/fcm-token');
    await http.put(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({'token': token}),
    );
  }

  // ── Box refill ────────────────────────────────────────────────

  Future<Map<String, dynamic>> startRefill() async {
    final url = Uri.parse('$baseUrl/api/box-refill/start');
    final response = await http.post(url, headers: await _authHeaders());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to start refill: ${response.statusCode}');
  }

  Future<Map<String, dynamic>?> getRefillState() async {
    final url = Uri.parse('$baseUrl/api/box-refill/current');
    final response = await http.get(url, headers: await _authHeaders());
    if (response.statusCode == 204) return null;
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get refill state: ${response.statusCode}');
  }

  Future<void> markSlotFilled(int slotNumber, String medicineId) async {
    final url = Uri.parse(
        '$baseUrl/api/box-refill/slots/$slotNumber/medications/$medicineId/fill');
    final response = await http.post(url, headers: await _authHeaders());
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to mark slot filled: ${response.statusCode}');
    }
  }

  Future<void> unmarkSlotFilled(int slotNumber, String medicineId) async {
    final url = Uri.parse(
        '$baseUrl/api/box-refill/slots/$slotNumber/medications/$medicineId/fill');
    final response = await http.delete(url, headers: await _authHeaders());
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to unmark slot: ${response.statusCode}');
    }
  }

  // ── Intake settings ──────────────────────────────────────────

  Future<Map<String, String>> getIntakeSettings() async {
    final url = Uri.parse('$baseUrl/api/intake-settings');
    final response = await http.get(url, headers: await _authHeaders());
    if (response.statusCode == 200) {
      return Map<String, String>.from(jsonDecode(response.body));
    }
    _throwApiException(response);
  }

  Future<Map<String, String>> updateIntakeSettings({
    required String morning,
    required String noon,
    required String evening,
  }) async {
    final url = Uri.parse('$baseUrl/api/intake-settings');
    final response = await http.put(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({'morning': morning, 'noon': noon, 'evening': evening}),
    );
    if (response.statusCode == 200) {
      return Map<String, String>.from(jsonDecode(response.body));
    }
    _throwApiException(response);
  }

  /// How many minutes before the scheduled time a dose becomes eligible for early intake.
  /// Also returned as part of getIntakeSettings()['earlyWindowMinutes'] — this is a dedicated
  /// setter so changing it never accidentally touches the reminder times.
  Future<Map<String, String>> updateEarlyWindowMinutes(int minutes) async {
    final url = Uri.parse('$baseUrl/api/intake-settings/early-window');
    final response = await http.put(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({'earlyWindowMinutes': minutes}),
    );
    if (response.statusCode == 200) {
      return Map<String, String>.from(jsonDecode(response.body));
    }
    _throwApiException(response);
  }

  /// DEMO-ONLY: remove after exhibition — how many minutes after the scheduled time a dose stays
  /// available before becoming MISSED. Default (production) is 60; this lets the demo screen turn
  /// it down to a couple of minutes for quick testing. Also returned as part of
  /// getIntakeSettings()['missedWindowMinutes'].
  Future<Map<String, String>> updateMissedWindowMinutes(int minutes) async {
    final url = Uri.parse('$baseUrl/api/intake-settings/missed-window');
    final response = await http.put(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({'missedWindowMinutes': minutes}),
    );
    if (response.statusCode == 200) {
      return Map<String, String>.from(jsonDecode(response.body));
    }
    _throwApiException(response);
  }

  // ── Caregiver management ────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCaregivers() async {
    final url = Uri.parse('$baseUrl/api/caregiver-links/mine');
    final response = await http.get(url, headers: await _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    _throwApiException(response);
  }

  Future<Map<String, dynamic>> addCaregiver(String email) async {
    final url = Uri.parse('$baseUrl/api/caregiver-links/mine');
    final response = await http.post(
      url,
      headers: await _authHeaders(json: true),
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    _throwApiException(response);
  }

  Future<void> removeCaregiver(int caregiverId) async {
    final url = Uri.parse('$baseUrl/api/caregiver-links/mine/$caregiverId');
    final response = await http.delete(url, headers: await _authHeaders());
    if (response.statusCode != 200) _throwApiException(response);
  }

}
