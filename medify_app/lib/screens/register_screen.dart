import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/medicine.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final ApiService _apiService = ApiService();

  DosageUnit _unit = DosageUnit.pills;
  TimePeriod? _timePeriod;
  InstructionOption _instructionOption = InstructionOption.none;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _saveMedicine() async {
    if (_timePeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Must choose time window')),
      );
      return;
    }

    final medicine = Medicine(
      id: const Uuid().v4(),
      name: _nameController.text,
      dosageAmount: double.tryParse(_amountController.text) ?? 1,
      dosageUnit: _unit,
      timePeriod: _timePeriod!,
      status: MedicationStatus.pending,
      instructionOption: _instructionOption,
      instructions: _instructionOption == InstructionOption.other
          ? _instructionsController.text
          : null,
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

  String _unitLabel(DosageUnit u) =>
      u.name[0].toUpperCase() + u.name.substring(1);

  String _timingLabel(TimePeriod t) {
    switch (t) {
      case TimePeriod.morning: return 'Morning';
      case TimePeriod.noon:    return 'Noon';
      case TimePeriod.evening: return 'Evening';
      default:                 return t.name;
    }
  }

  String _instructionLabel(InstructionOption o) {
    switch (o) {
      case InstructionOption.none:         return 'None';
      case InstructionOption.afterFood:    return 'After food';
      case InstructionOption.emptyStomach: return 'Empty stomach';
      case InstructionOption.other:        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    const scheduledTimings = [TimePeriod.morning, TimePeriod.noon, TimePeriod.evening];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medicine'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset('assets/medify-logo.png', height: 56),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Medicine name
          Text('Medicine Name', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'e.g. Advil'),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Dosage
          Text('Dosage', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Amount'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _styledDropdown<DosageUnit>(
                value: _unit,
                items: DosageUnit.values,
                label: _unitLabel,
                onChanged: (v) => setState(() => _unit = v),
              )),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Time window — required
          Text('Schedule Time', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          _styledDropdown<TimePeriod>(
            value: _timePeriod,
            hint: 'Choose time window',
            items: scheduledTimings,
            label: _timingLabel,
            onChanged: (v) => setState(() => _timePeriod = v),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Instructions
          Text('Instructions', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          _styledDropdown<InstructionOption>(
            value: _instructionOption,
            items: InstructionOption.values,
            label: _instructionLabel,
            onChanged: (v) => setState(() => _instructionOption = v),
          ),

          if (_instructionOption == InstructionOption.other) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _instructionsController,
              decoration: const InputDecoration(hintText: 'Describe instructions...'),
            ),
          ],

          const SizedBox(height: AppSpacing.xxxl),

          ElevatedButton(
            onPressed: _saveMedicine,
            child: const Text('Save'),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _styledDropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: hint != null
              ? Text(hint, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary))
              : null,
          onChanged: (v) => onChanged(v as T),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(label(e), style: AppTextStyles.body),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
