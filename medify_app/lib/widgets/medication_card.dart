import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../theme/app_theme.dart';

class MedicationCard extends StatelessWidget {
  final Medicine medicine;

  const MedicationCard({super.key, required this.medicine});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: AppRadius.mdBorder,
              ),
              child: const Icon(Icons.medication, color: AppColors.primary),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medicine.name, style: AppTextStyles.bodyLg),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatAmount(medicine.dosageAmount)} ${medicine.dosageUnit.name} • ${medicine.timePeriod.name}',
                    style: AppTextStyles.bodySm,
                  ),
                  const SizedBox(height: 2),
                  Text(_instructionLabel, style: AppTextStyles.caption),
                ],
              ),
            ),

            _StatusBadge(status: medicine.status),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    return amount == amount.truncateToDouble()
        ? amount.toInt().toString()
        : amount.toString();
  }

  String get _instructionLabel {
    switch (medicine.instructionOption) {
      case InstructionOption.none:         return 'None';
      case InstructionOption.afterFood:    return 'After food';
      case InstructionOption.emptyStomach: return 'Empty stomach';
      case InstructionOption.other:        return medicine.instructions ?? '';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final MedicationStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor.withValues(alpha: 0.12),
        borderRadius: AppRadius.smBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _bgColor),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _bgColor,
            ),
          ),
        ],
      ),
    );
  }

  String get _label {
    switch (status) {
      case MedicationStatus.taken:   return 'Taken';
      case MedicationStatus.pending: return 'Upcoming';
      case MedicationStatus.missed:  return 'Missed';
    }
  }

  IconData get _icon {
    switch (status) {
      case MedicationStatus.taken:   return Icons.check_circle_outline;
      case MedicationStatus.pending: return Icons.access_time;
      case MedicationStatus.missed:  return Icons.warning_amber_outlined;
    }
  }

  Color get _bgColor {
    switch (status) {
      case MedicationStatus.taken:   return AppColors.success;
      case MedicationStatus.pending: return AppColors.warning;
      case MedicationStatus.missed:  return AppColors.error;
    }
  }
}
