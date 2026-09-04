import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../widgets/app_sidebar.dart';
import 'fill_box_guide_screen.dart';
import 'intake_history_screen.dart';
import 'settings_screen.dart';

class CaregiverScreen extends StatefulWidget {
  final int userId;

  const CaregiverScreen({super.key, required this.userId});

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _todayIntakes = [];
  List<Medicine> _medicines = [];
  List<Map<String, dynamic>> _alerts = [];
  String? _patientName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _apiService.getTodayIntakes(),
        _apiService.getMedicines(),
        _apiService.getNotificationsLog(widget.userId),
        _apiService.getCurrentBackendUser(),
      ]);

      if (!mounted) return;
      final me = results[3] as Map<String, dynamic>?;
      final patientFirstName = me?['patientFirstName'] as String?;
      final patientLastName = me?['patientLastName'] as String?;
      setState(() {
        // Only today's own intakes — previous-day unresolved intakes are deliberately not
        // surfaced here; the rolling 24h Alerts feed and Intake History already cover them.
        _todayIntakes = (results[0] as TodayIntakes).today;
        _medicines    = results[1] as List<Medicine>;
        _alerts = (results[2] as List<Map<String, dynamic>>)
            .where((n) => n['type'] == 'MISSED_INTAKE' || n['type'] == 'INCOMPLETE_INTAKE')
            .toList()
          ..sort((a, b) =>
              (b['sentTime'] as String).compareTo(a['sentTime'] as String));
        _patientName = [patientFirstName, patientLastName]
            .where((n) => n != null && n.isNotEmpty)
            .join(' ');
        if (_patientName!.isEmpty) _patientName = null;
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('CaregiverScreen load failed', e, 'Caregiver');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ── Computed ─────────────────────────────────────────────────

  int get _takenCount =>
      _todayIntakes.where((i) => i['status'] == 'TAKEN').length;

  bool _isScheduled(Medicine m) =>
      m.enabled &&
      (m.disabledUntil == null || m.disabledUntil!.isBefore(DateTime.now()));

  List<Medicine> _medicinesForTiming(String timing) => _medicines
      .where((m) => m.timePeriod.name.toUpperCase() == timing.toUpperCase() && _isScheduled(m))
      .toList();

  Future<void> _goToFillGuide() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FillBoxGuideScreen()),
    );
  }

  Future<void> _goToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen(isPatient: false)),
    );
  }

  Future<void> _goToHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const IntakeHistoryScreen()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _patientName == null
            ? const Text('Caregiver View')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Caregiver View', style: AppTextStyles.caption),
                  Text(_patientName!, style: AppTextStyles.h3),
                ],
              ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset('assets/medify-logo.png', height: 56),
          ),
        ],
      ),
      drawer: AppSidebar(
        onFillBox: _goToFillGuide,
        onHistory: _goToHistory,
        onSettings: _goToSettings,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: AppSpacing.xxl),

                  _buildSectionHeader(
                    'Medication Schedule',
                    Icons.medication_outlined,
                    AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_medicines.isEmpty)
                    _buildEmptyState('No medicines registered')
                  else
                    ..._buildMedicineSchedule(),

                  const SizedBox(height: AppSpacing.xxl),

                  _buildSectionHeader(
                    "Today's Intake Status",
                    Icons.calendar_today_outlined,
                    AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_todayIntakes.isEmpty)
                    _buildEmptyState('No intakes recorded today')
                  else
                    ..._todayIntakes.map(_buildIntakeTile),

                  const SizedBox(height: AppSpacing.xxl),

                  _buildSectionHeader(
                    'Alerts${_alerts.isNotEmpty ? ' (${_alerts.length})' : ''}',
                    Icons.warning_amber_rounded,
                    _alerts.isNotEmpty
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_alerts.isEmpty)
                    _buildEmptyState('No alerts')
                  else
                    ..._alerts.map(_buildAlertCard),
                ],
              ),
            ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    const allTimings = ['MORNING', 'NOON', 'EVENING'];
    final total  = allTimings.where((t) => _medicinesForTiming(t).isNotEmpty).length;
    final taken  = _todayIntakes.where((i) => i['status'] == 'TAKEN').length;
    final missed = _todayIntakes.where((i) => i['status'] == 'MISSED').length;
    final progress = total == 0 ? 0.0 : taken / total;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text('Patient',
                        style: AppTextStyles.bodySm
                            .copyWith(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('$taken / $total windows completed today',
                    style: AppTextStyles.h3.copyWith(color: Colors.white)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: AppRadius.smBorder,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                if (missed > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orangeAccent, size: 14),
                      const SizedBox(width: 4),
                      Text('$missed missed',
                          style: AppTextStyles.bodySm
                              .copyWith(color: Colors.orangeAccent)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Text(
                  total == 0 ? '—' : '$taken/$total',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTextStyles.h3),
      ],
    );
  }

  List<Widget> _buildMedicineSchedule() {
    const order = ['MORNING', 'NOON', 'EVENING'];
    return order
        .map((timing) => MapEntry(timing, _medicinesForTiming(timing)))
        .where((e) => e.value.isNotEmpty)
        .map((e) => _buildTimingGroup(e.key, e.value))
        .toList();
  }

  Widget _buildTimingGroup(String timing, List<Medicine> meds) {
    final color = _timingColor(timing);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdBorder,
            ),
            child: Icon(_timingIcon(timing), color: color, size: 18),
          ),
          title: Text(_capitalize(timing), style: AppTextStyles.bodyLg),
          subtitle: Text('${meds.length} medicine${meds.length == 1 ? '' : 's'}',
              style: AppTextStyles.bodySm),
          children: [
            const Divider(height: 1),
            ...meds.map(
              (m) => ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: const Icon(Icons.medication,
                      color: AppColors.primary, size: 16),
                ),
                title: Text(m.name, style: AppTextStyles.body),
                subtitle: Text(
                  '${_formatAmount(m.dosageAmount)} ${m.dosageUnit.name}'
                  '${_instructionLabel(m)}',
                  style: AppTextStyles.caption,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _buildIntakeTile(Map<String, dynamic> intake) {
    final status   = intake['status']  as String? ?? 'PENDING';
    final timing   = intake['timing']  as String? ?? '';
    final start    = _formatTime(intake['windowStartTime'] as String? ?? '');
    final end      = _formatTime(intake['windowEndTime']   as String? ?? '');
    final color    = _statusColor(status);
    final meds     = _medicinesForTiming(timing);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              color: _timingColor(timing).withValues(alpha: 0.12),
              borderRadius: AppRadius.mdBorder,
            ),
            child: Icon(_timingIcon(timing),
                color: _timingColor(timing), size: 20),
          ),
          title: Text(_capitalize(timing), style: AppTextStyles.bodyLg),
          subtitle: start.isNotEmpty && end.isNotEmpty
              ? Text('$start – $end', style: AppTextStyles.bodySm)
              : null,
          trailing: _StatusBadge(status: status, color: color),
          children: [
            const Divider(height: 1),
            if (meds.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('No medicines for this window',
                    style: AppTextStyles.bodySm),
              )
            else
              ...meds.map(
                (m) => ListTile(
                  dense: true,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: const Icon(Icons.medication,
                        color: AppColors.primary, size: 16),
                  ),
                  title: Text(m.name, style: AppTextStyles.body),
                  subtitle: Text(
                    '${_formatAmount(m.dosageAmount)} ${m.dosageUnit.name}'
                    '${_instructionLabel(m)}',
                    style: AppTextStyles.caption,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final message  = alert['message']  as String? ?? '';
    final sentTime = alert['sentTime'] as String? ?? '';
    final isIncomplete = alert['type'] == 'INCOMPLETE_INTAKE';
    // The intake this alert refers to may have since been taken (a late approval, or — for
    // INCOMPLETE — a late IR confirmation now that markTaken accepts that path too). Still shown
    // (not removed) until the alert itself ages out of the 24h window, just relabeled in orange
    // instead of the usual red so a caregiver can tell it's since been resolved at a glance.
    final resolvedAsTaken = alert['resolvedAsTaken'] as bool? ?? false;
    final icon = isIncomplete ? Icons.hourglass_disabled : Icons.warning_amber_rounded;
    final label = resolvedAsTaken
        ? (isIncomplete ? 'Taken after incomplete' : 'Taken after missed')
        : (isIncomplete ? 'Incomplete' : 'Missed');
    final color = resolvedAsTaken ? AppColors.warning : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdBorder,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: AppTextStyles.body),
                if (sentTime.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_formatTime(sentTime), style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(text,
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
      );

  // ── Helpers ───────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'TAKEN':      return AppColors.success;
      case 'MISSED':     return AppColors.error;
      case 'INCOMPLETE': return AppColors.error;
      case 'POSTPONED':  return AppColors.warning;
      case 'SKIPPED':    return AppColors.textSecondary;
      case 'DISPENSING':
      case 'DISPENSED':  return AppColors.primary;
      default:           return AppColors.warning;
    }
  }

  IconData _timingIcon(String timing) {
    switch (timing.toUpperCase()) {
      case 'MORNING': return Icons.wb_twilight;
      case 'NOON':    return Icons.wb_sunny_outlined;
      case 'EVENING': return Icons.nights_stay_outlined;
      default:        return Icons.schedule;
    }
  }

  Color _timingColor(String timing) {
    switch (timing.toUpperCase()) {
      case 'MORNING': return const Color(0xFFF59F0A);
      case 'NOON':    return AppColors.primary;
      case 'EVENING': return const Color(0xFF7C6EF8);
      default:        return AppColors.textSecondary;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _formatAmount(double amount) =>
      amount == amount.truncateToDouble()
          ? amount.toInt().toString()
          : amount.toString();

  String _instructionLabel(Medicine m) {
    switch (m.instructionOption) {
      case InstructionOption.none:         return ' · none';
      case InstructionOption.afterFood:    return ' · after food';
      case InstructionOption.emptyStomach: return ' · empty stomach';
      case InstructionOption.other:
        return m.instructions != null ? ' · ${m.instructions}' : '';
    }
  }
}

// ── Status Badge ──────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  String get _label {
    switch (status) {
      case 'TAKEN':      return 'Taken';
      case 'MISSED':     return 'Missed';
      case 'INCOMPLETE': return 'Incomplete';
      case 'POSTPONED':  return 'Postponed';
      case 'SKIPPED':    return 'Skipped';
      case 'DISPENSING': return 'Dispensing';
      case 'DISPENSED':  return 'Waiting for pickup';
      default:           return 'Pending';
    }
  }

  IconData get _icon {
    switch (status) {
      case 'TAKEN':      return Icons.check_circle_outline;
      case 'MISSED':     return Icons.cancel_outlined;
      case 'INCOMPLETE': return Icons.hourglass_disabled;
      case 'POSTPONED':  return Icons.access_time;
      case 'SKIPPED':    return Icons.remove_circle_outline;
      case 'DISPENSING': return Icons.autorenew;
      case 'DISPENSED':  return Icons.hourglass_bottom;
      default:           return Icons.radio_button_unchecked;
    }
  }
}
