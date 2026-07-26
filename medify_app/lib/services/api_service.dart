import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/medicine.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080'; // for browser
  //static const String baseUrl = 'http://192.168.7.17:8080'; // for android
  static const String embeddedBaseUrl = 'http://192.168.7.21'; // embedded url

  Future<List<Medicine>> getMedicines() async {
    final url = Uri.parse('$baseUrl/api/medications');
    final response = await http.get(url);

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
      headers: {'Content-Type': 'application/json'},
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

  // ── Notifications ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getNotification() async {
    final url = Uri.parse('$baseUrl/api/notification');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to get notification: ${response.statusCode}');
  }

  Future<void> sendNotification(String message, {int? intakeId}) async {
    final url = Uri.parse('$baseUrl/api/notification');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
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

  Future<Map<String, dynamic>> approveIntake(int intakeId) async {
    final url = Uri.parse('$baseUrl/api/intakes/$intakeId/approve');
    final response = await http.patch(url);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to approve intake: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> releaseIntake(int intakeId) async {
    final url = Uri.parse('$baseUrl/api/intakes/$intakeId/released');
    final response = await http.patch(url);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to release intake: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> skipIntake(int intakeId) async {
    final url = Uri.parse('$baseUrl/api/intakes/$intakeId/skip');
    final response = await http.patch(url);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to skip intake: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> postponeIntake(int intakeId) async {
    final url = Uri.parse('$baseUrl/api/intakes/$intakeId/postpone');
    final response = await http.patch(url);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to postpone intake: ${response.statusCode}');
  }

  Future<List<Map<String, dynamic>>> getTodayIntakes() async {
    final url = Uri.parse('$baseUrl/api/intakes/today');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to get today intakes: ${response.statusCode}');
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
      headers: {'Content-Type': 'application/json'},
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
    final response = await http.delete(url);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete medicine: ${response.statusCode}');
    }
  }

  Future<Medicine> disableMedicine(String id) async {
    final url = Uri.parse('$baseUrl/api/medications/$id/disable');
    final response = await http.patch(url);
    if (response.statusCode == 200) return Medicine.fromJson(jsonDecode(response.body));
    throw Exception('Failed to disable medicine: ${response.statusCode}');
  }

  Future<Medicine> enableMedicine(String id) async {
    final url = Uri.parse('$baseUrl/api/medications/$id/enable');
    final response = await http.patch(url);
    if (response.statusCode == 200) return Medicine.fromJson(jsonDecode(response.body));
    throw Exception('Failed to enable medicine: ${response.statusCode}');
  }

  Future<Medicine> disableMedicineUntil(String id, DateTime until) async {
    final url = Uri.parse('$baseUrl/api/medications/$id/disable-until');
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'until': until.toIso8601String().split('.').first}),
    );
    if (response.statusCode == 200) return Medicine.fromJson(jsonDecode(response.body));
    throw Exception('Failed to disable medicine until: ${response.statusCode}');
  }

  Future<Medicine> clearDisabledUntil(String id) async {
    final url = Uri.parse('$baseUrl/api/medications/$id/clear-until');
    final response = await http.patch(url);
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
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to get notifications log: ${response.statusCode}');
  }

  // ── Device ────────────────────────────────────────────────────

  Future<bool> dispenseFromDevice() async {
    final url = Uri.parse('$embeddedBaseUrl/move');
    final response = await http.get(url).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = response.body.trim();
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['status'] == 'OK';
      } catch (_) {
        // device returned plain text (e.g. "OK")
        return body.toUpperCase() == 'OK';
      }
    }

    throw Exception('Failed to dispense from device: ${response.statusCode}');
  }
}
