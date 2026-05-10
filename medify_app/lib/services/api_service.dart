import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/medicine.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080';
  static const String embeddedBaseUrl = 'http://192.168.7.18'; // embedded url
  
  Future<List<Medicine>> getMedicines() async {
    final url = Uri.parse('$baseUrl/api/medicines');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Medicine.fromJson(json)).toList();
    }

    throw Exception('Failed to load medicines: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> registerMedicine(Medicine medicine) async {
    final url = Uri.parse('$baseUrl/api/medicines');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': 1,
        'name': medicine.name,
        'timing': medicine.timePeriod.name.toUpperCase(),
        'description': medicine.instructionOption == InstructionOption.other
            ? medicine.instructions
            : medicine.instructionOption.name,
        'active': medicine.enabled,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to register medicine: ${response.statusCode}');
  }

  Future<String> sendNotification(String message) async {
    final url = Uri.parse('$baseUrl/api/notification');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': message,
      }),
    );

    if (response.statusCode == 200) {
      return response.body;
    }

    throw Exception('Failed to send notification: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getNotification() async {
    final url = Uri.parse('$baseUrl/api/notification');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to get notification: ${response.statusCode}');
  }

  Future<bool> dispenseFromDevice() async {
    final url = Uri.parse('$embeddedBaseUrl/move');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      return body['status'] == 'OK';
    }

    throw Exception('Failed to dispense from device: ${response.statusCode}');    
  }

}
