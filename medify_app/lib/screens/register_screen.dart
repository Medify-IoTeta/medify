import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/medicine.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final ApiService _apiService = ApiService();

  DosageUnit _unit = DosageUnit.pills;
  TimePeriod _timePeriod = TimePeriod.morning;
  InstructionOption _instructionOption = InstructionOption.afterFood;

  Future<void> _saveMedicine() async {
    final medicine = Medicine(
      id: const Uuid().v4(),
      name: _nameController.text,
      dosageAmount: double.tryParse(_amountController.text) ?? 1,
      dosageUnit: _unit,
      timePeriod: _timePeriod,
      status: MedicationStatus.pending,
      instructionOption: _instructionOption,
    );
    try {
      final result = await _apiService.registerMedicine(medicine);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Medicine saved')),
      );
      Navigator.pop(context, medicine);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Medicine")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Medicine Name"),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount"),
            ),
            const SizedBox(height: 20),
            DropdownButton<DosageUnit>(
              value: _unit,
              onChanged: (value) => setState(() => _unit = value!),
              items: DosageUnit.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
            ),
            const SizedBox(height: 20),
            DropdownButton<TimePeriod>(
              value: _timePeriod,
              onChanged: (value) => setState(() => _timePeriod = value!),
              items: TimePeriod.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
            ),
            const SizedBox(height: 20),
            DropdownButton<InstructionOption>(
              value: _instructionOption,
              onChanged: (value) => setState(() => _instructionOption = value!),
              items: InstructionOption.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _saveMedicine,
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
