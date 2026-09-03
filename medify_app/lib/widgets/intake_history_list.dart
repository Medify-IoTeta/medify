import 'package:flutter/material.dart';

import '../models/intake_history_entry.dart';
import '../theme/app_theme.dart';

/// Shared intake history list — used as-is by both the patient app and the caregiver view so the
/// two always render the same data the same way. Groups entries (already most-recent-first from
/// the backend) by calendar day, in order.
class IntakeHistoryList extends StatelessWidget {
  final List<IntakeHistoryEntry> entries;

  const IntakeHistoryList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text('No intake history yet', style: AppTextStyles.body),
      );
    }

    final Map<DateTime, List<IntakeHistoryEntry>> groups = {};
    for (final entry in entries) {
      final day = DateTime(
          entry.scheduledTime.year, entry.scheduledTime.month, entry.scheduledTime.day);
      groups.putIfAbsent(day, () => []).add(entry);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(_dayLabel(day), style: AppTextStyles.h3),
              ),
              ...groups[day]!.map((entry) => _HistoryEntryTile(entry: entry)),
            ],
          ),
        );
      },
    );
  }

  String _dayLabel(DateTime day) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final diff = todayDate.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${weekdays[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';
  }
}

class _HistoryEntryTile extends StatelessWidget {
  final IntakeHistoryEntry entry;

  const _HistoryEntryTile({required this.entry});

  IconData get _timingIcon {
    switch (entry.timing) {
      case 'MORNING': return Icons.wb_twilight;
      case 'NOON':    return Icons.wb_sunny_outlined;
      case 'EVENING': return Icons.nights_stay_outlined;
      default:        return Icons.schedule;
    }
  }

  ({String label, Color color, IconData icon}) get _outcomeDisplay {
    switch (entry.outcome) {
      case IntakeOutcome.takenOnTime:
        return (label: 'Taken on time', color: AppColors.success, icon: Icons.check_circle_outline);
      case IntakeOutcome.takenAfterPostponed:
        return (label: 'Taken after postponed', color: AppColors.success, icon: Icons.check_circle_outline);
      case IntakeOutcome.takenAfterMissed:
        return (label: 'Taken after missed', color: AppColors.success, icon: Icons.check_circle_outline);
      case IntakeOutcome.missed:
        return (label: 'Missed', color: AppColors.error, icon: Icons.cancel_outlined);
      case IntakeOutcome.skipped:
        return (label: 'Skipped', color: AppColors.textSecondary, icon: Icons.remove_circle_outline);
      case IntakeOutcome.incomplete:
        return (label: 'Incomplete', color: AppColors.error, icon: Icons.hourglass_disabled);
      case IntakeOutcome.pending:
        return (label: 'Pending', color: AppColors.textSecondary, icon: Icons.radio_button_unchecked);
      case IntakeOutcome.approved:
        return (label: 'Approved', color: AppColors.primary, icon: Icons.check_circle);
      case IntakeOutcome.postponed:
        return (label: 'Postponed', color: AppColors.warning, icon: Icons.access_time);
      case IntakeOutcome.dispensing:
        return (label: 'Dispensing', color: AppColors.primary, icon: Icons.autorenew);
      case IntakeOutcome.dispensed:
        return (label: 'Waiting for pickup', color: AppColors.primary, icon: Icons.hourglass_bottom);
    }
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatLateness(int minutes) {
    final early = minutes < 0;
    final abs = minutes.abs();
    final hours = abs ~/ 60;
    final mins = abs % 60;
    final duration = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    return early ? '$duration early' : '$duration late';
  }

  @override
  Widget build(BuildContext context) {
    final display = _outcomeDisplay;
    final label = entry.timing[0] + entry.timing.substring(1).toLowerCase();
    final takenAt = entry.takenAt;
    final lateness = entry.latenessMinutes;

    String? detail;
    if (takenAt != null) {
      detail = 'Taken at ${_formatTime(takenAt)}';
      if (entry.outcome == IntakeOutcome.takenAfterMissed && lateness != null) {
        detail += ' — ${_formatLateness(lateness)}';
      } else if (entry.outcome == IntakeOutcome.takenAfterPostponed && lateness != null) {
        detail += ' (${_formatLateness(lateness)})';
      }
    } else if (entry.wasPostponed && entry.outcome != IntakeOutcome.postponed) {
      detail = 'Was postponed earlier';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: display.color.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdBorder,
            ),
            child: Icon(_timingIcon, color: display.color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('$label · ${_formatTime(entry.scheduledTime)}',
                          style: AppTextStyles.bodyLg),
                    ),
                    Icon(display.icon, size: 14, color: display.color),
                    const SizedBox(width: 4),
                    Text(display.label,
                        style: AppTextStyles.label.copyWith(color: display.color)),
                  ],
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: AppTextStyles.bodySm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
