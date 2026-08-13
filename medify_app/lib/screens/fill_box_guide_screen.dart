import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'fill_box_wizard_screen.dart';

const int totalBoxSlots = 13;

class FillBoxGuideScreen extends StatefulWidget {
  const FillBoxGuideScreen({super.key});

  @override
  State<FillBoxGuideScreen> createState() => _FillBoxGuideScreenState();
}

class _FillBoxGuideScreenState extends State<FillBoxGuideScreen> {
  final ApiService _apiService = ApiService();

  bool _loading = true;
  bool _polling = true;
  Map<String, dynamic>? _refillState;
  List<Medicine> _medicines = [];

  @override
  void initState() {
    super.initState();
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _polling = false;
    super.dispose();
  }

  // Refreshes refill state every few seconds so a fill made from the other
  // role's session (patient vs. caregiver) shows up here without a manual pull.
  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!_polling || !mounted) return false;
      try {
        final state = await _apiService.getRefillState();
        if (mounted) setState(() => _refillState = state);
      } catch (e) {
        AppLogger.debug('Refill state poll failed, retrying: $e', 'FillBox');
      }
      return _polling && mounted;
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _apiService.getRefillState(),
        _apiService.getMedicines(),
      ]);
      if (!mounted) return;
      setState(() {
        _refillState = results[0] as Map<String, dynamic>?;
        _medicines   = results[1] as List<Medicine>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('$e');
    }
  }

  Future<void> _startNewRefill() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Pill Box'),
        content: const Text(
            'Use this only if you have physically emptied and restarted the box from slot 1. All fill progress will be cleared. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final state = await _apiService.startRefill();
      if (!mounted) return;
      setState(() => _refillState = state);
    } catch (e) {
      _showError('$e');
    }
  }

  Future<void> _openWizard(Medicine medicine) async {
    final cells = _cellsForMedicine(medicine);
    if (cells.isEmpty) {
      _showError('No cells scheduled for this medicine.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FillBoxWizardScreen(
          medicine: medicine,
          cellNumbers: cells,
          currentSlot: _currentSlot,
          isFilled: (slot) => _isFilled(slot, medicine.id),
        ),
      ),
    );
    _load();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // ── Computed ──────────────────────────────────────────────────

  List<Medicine> get _scheduledMedicines =>
      _medicines.where(_isScheduled).toList();

  bool _isScheduled(Medicine m) =>
      m.enabled &&
      (m.disabledUntil == null || m.disabledUntil!.isBefore(DateTime.now()));

  List<String> get _activeTimings {
    const order = ['MORNING', 'NOON', 'EVENING'];
    return order
        .where((t) =>
            _scheduledMedicines.any((m) => m.timePeriod.name.toUpperCase() == t))
        .toList();
  }

  int get _currentSlot =>
      (_refillState?['currentSlot'] as num?)?.toInt() ?? 0;

  List<Map<String, dynamic>> get _filledCells =>
      ((_refillState?['filledCells'] as List?)?.cast<Map<String, dynamic>>()) ??
      [];

  bool _isFilled(int slot, String medicineId) => _filledCells.any((c) =>
      (c['slotNumber'] as num).toInt() == slot &&
      c['medicineId'].toString() == medicineId);

  int _filledCountFor(String medicineId) => _filledCells
      .where((c) => c['medicineId'].toString() == medicineId)
      .length;

  // Cell indices (0-based) belonging to this medicine's timing window,
  // ordered starting from the box's current position.
  List<int> _cellsForMedicine(Medicine m) {
    final timings = _activeTimings;
    final myTiming = m.timePeriod.name.toUpperCase();
    if (timings.isEmpty || !timings.contains(myTiming)) return [];
    final allCells = List.generate(totalBoxSlots, (i) => i)
        .where((i) => timings[i % timings.length] == myTiming)
        .toList();
    final splitAt = allCells.indexWhere((i) => i >= _currentSlot);
    if (splitAt <= 0) return allCells;
    return [...allCells.sublist(splitAt), ...allCells.sublist(0, splitAt)];
  }

  List<Medicine> get _sortedScheduledMedicines {
    final timings = _activeTimings;
    final meds = List<Medicine>.from(_scheduledMedicines);
    meds.sort((a, b) {
      final ai = timings.indexOf(a.timePeriod.name.toUpperCase());
      final bi = timings.indexOf(b.timePeriod.name.toUpperCase());
      if (ai != bi) return ai.compareTo(bi);
      return a.name.compareTo(b.name);
    });
    return meds;
  }

  String _timingLabel(String t) {
    switch (t) {
      case 'MORNING': return 'Morning';
      case 'NOON':    return 'Noon';
      case 'EVENING': return 'Evening';
      default:        return t;
    }
  }

  IconData _timingIcon(String t) {
    switch (t) {
      case 'MORNING': return Icons.wb_twilight;
      case 'NOON':    return Icons.wb_sunny_outlined;
      case 'EVENING': return Icons.nights_stay_outlined;
      default:        return Icons.schedule;
    }
  }

  Color _timingColor(String t) {
    switch (t) {
      case 'MORNING': return const Color(0xFFF59F0A);
      case 'NOON':    return AppColors.primary;
      case 'EVENING': return const Color(0xFF7C6EF8);
      default:        return AppColors.textSecondary;
    }
  }

  String _formatAmount(double a) =>
      a == a.truncateToDouble() ? a.toInt().toString() : a.toString();

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill Pill Box'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset('assets/medify-logo.png', height: 80),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_refillState == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 72, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.lg),
              Text('No active refill session.',
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xl),
              _BigButton(
                label: 'Start First Refill',
                icon: Icons.add_circle_outline,
                onPressed: _startNewRefill,
              ),
            ],
          ),
        ),
      );
    }

    final medicines = _sortedScheduledMedicines;

    if (medicines.isEmpty) {
      return Center(
        child: Text('No active medicines registered.',
            style: AppTextStyles.h3
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      );
    }

    final totalCells =
        medicines.fold<int>(0, (sum, m) => sum + _cellsForMedicine(m).length);
    final filledCells = medicines.fold<int>(
        0, (sum, m) => sum + _filledCountFor(m.id));

    return Column(
      children: [
        // ── Summary bar ───────────────────────────────────────
        Container(
          width: double.infinity,
          color: AppColors.muted,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Text('$filledCells / $totalCells cells filled',
                  style: AppTextStyles.bodyLg),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.smBorder,
                  child: LinearProgressIndicator(
                    value: totalCells == 0 ? 0 : filledCells / totalCells,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Text(
            'Choose a medicine to see where it goes',
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary),
          ),
        ),

        // ── Medicine list ─────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: medicines.length + 1, // +1 for reset button
            itemBuilder: (_, index) {
              if (index == medicines.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _startNewRefill,
                      icon: const Icon(Icons.restart_alt, size: 20),
                      label: const Text('Reset Box (Start From Slot 1)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding:
                            const EdgeInsets.symmetric(vertical: 18),
                        textStyle: AppTextStyles.bodyLg,
                      ),
                    ),
                  ),
                );
              }

              final medicine = medicines[index];
              final timing = medicine.timePeriod.name.toUpperCase();
              final total = _cellsForMedicine(medicine).length;
              final filled = _filledCountFor(medicine.id);
              final complete = total > 0 && filled >= total;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _MedicineRow(
                  medicine: medicine,
                  timingLabel: _timingLabel(timing),
                  timingIcon: _timingIcon(timing),
                  timingColor: _timingColor(timing),
                  formatAmount: _formatAmount,
                  filledCount: filled,
                  totalCount: total,
                  complete: complete,
                  onTap: () => _openWizard(medicine),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Medicine row ─────────────────────────────────────────────

class _MedicineRow extends StatelessWidget {
  final Medicine medicine;
  final String timingLabel;
  final IconData timingIcon;
  final Color timingColor;
  final String Function(double) formatAmount;
  final int filledCount;
  final int totalCount;
  final bool complete;
  final VoidCallback onTap;

  const _MedicineRow({
    required this.medicine,
    required this.timingLabel,
    required this.timingIcon,
    required this.timingColor,
    required this.formatAmount,
    required this.filledCount,
    required this.totalCount,
    required this.complete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = complete ? AppColors.success : AppColors.warning;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgBorder,
      child: InkWell(
        borderRadius: AppRadius.lgBorder,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgBorder,
            border: Border.all(
              color: complete ? AppColors.success : AppColors.border,
              width: complete ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: timingColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(timingIcon, size: 26, color: timingColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timingLabel  ·  ${formatAmount(medicine.dosageAmount)} ${medicine.dosageUnit.name}',
                      style: AppTextStyles.bodyLg
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smBorder,
                  border: Border.all(color: badgeColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      complete
                          ? Icons.check_circle_outline
                          : Icons.pending_outlined,
                      size: 16,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$filledCount / $totalCount',
                      style: AppTextStyles.label.copyWith(color: badgeColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
