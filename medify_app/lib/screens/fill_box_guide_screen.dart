import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'fill_box_wizard_screen.dart';

class FillBoxGuideScreen extends StatefulWidget {
  const FillBoxGuideScreen({super.key});

  @override
  State<FillBoxGuideScreen> createState() => _FillBoxGuideScreenState();
}

class _FillBoxGuideScreenState extends State<FillBoxGuideScreen> {
  final ApiService _apiService = ApiService();

  bool _loading = true;
  bool _polling = true;
  List<Map<String, dynamic>> _slots = [];
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

  // Refreshes live so a fill (or a dispense, which clears a slot) made from the other role's
  // session, or by the device itself, shows up here without a manual pull.
  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!_polling || !mounted) return false;
      try {
        final slots = await _apiService.getRefillSlots();
        if (mounted) setState(() => _slots = slots);
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
        _apiService.getRefillSlots(),
        _apiService.getMedicines(),
      ]);
      if (!mounted) return;
      setState(() {
        _slots     = results[0] as List<Map<String, dynamic>>;
        _medicines = results[1] as List<Medicine>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('$e');
    }
  }

  Future<void> _openWizard(Medicine medicine) async {
    final cells = _missingCellsFor(medicine);
    if (cells.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${medicine.name} is already in every one of its cells.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FillBoxWizardScreen(medicine: medicine, cellNumbers: cells),
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

  List<Map<String, dynamic>> _slotsForTiming(String timing) =>
      _slots.where((s) => s['timing'] == timing).toList();

  /// 0-based cell numbers currently missing this medicine, in physical slot order — exactly what
  /// the backend says needs it, never client-computed.
  List<int> _missingCellsFor(Medicine m) => _slotsForTiming(m.timePeriod.name.toUpperCase())
      .where((s) => (s['missingMedicineIds'] as List).any((id) => id.toString() == m.id))
      .map((s) => s['slotNumber'] as int)
      .toList();

  int _filledCountFor(Medicine m) => _slotsForTiming(m.timePeriod.name.toUpperCase())
      .where((s) => (s['actualMedicineIds'] as List).any((id) => id.toString() == m.id))
      .length;

  int _totalCellsFor(Medicine m) => _slotsForTiming(m.timePeriod.name.toUpperCase()).length;

  /// Slots that physically contain a medicine no longer part of the current active schedule —
  /// e.g. it was disabled/removed/retimed since it was loaded. The app can't know pills were
  /// physically removed, so this stays visible until a human clears it (or the medicine becomes
  /// active for that slot's timing again).
  List<Map<String, dynamic>> get _slotsWithUnexpectedContents =>
      _slots.where((s) => (s['unexpectedMedicineIds'] as List).isNotEmpty).toList();

  String _medicineLabel(dynamic medicineId) {
    final match = _medicines.where((m) => m.id == medicineId.toString());
    return match.isEmpty ? 'a removed/changed medication' : match.first.name;
  }

  List<Medicine> get _sortedScheduledMedicines {
    const timings = ['MORNING', 'NOON', 'EVENING'];
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
    if (_slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text('No pill box registered yet.',
              style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
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

    final totalCells = medicines.fold<int>(0, (sum, m) => sum + _totalCellsFor(m));
    final filledCells = medicines.fold<int>(0, (sum, m) => sum + _filledCountFor(m));
    final unexpected = _slotsWithUnexpectedContents;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Summary bar ───────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: AppRadius.mdBorder,
            ),
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

          if (unexpected.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: AppRadius.mdBorder,
                border: Border.all(color: AppColors.warning),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Cells to physically check',
                          style: AppTextStyles.bodyLg.copyWith(color: AppColors.warning)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final slot in unexpected)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Cell ${(slot['slotNumber'] as int) + 1}: still has '
                        '${(slot['unexpectedMedicineIds'] as List).map(_medicineLabel).join(', ')} '
                        '— no longer part of the active schedule for this cell. Remove it if it\'s no longer taken.',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.warning),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          Text('Choose a medicine to see which cells it still needs',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),

          // ── Medicine list ─────────────────────────────────────
          for (final medicine in medicines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _MedicineRow(
                medicine: medicine,
                timingLabel: _timingLabel(medicine.timePeriod.name.toUpperCase()),
                timingIcon: _timingIcon(medicine.timePeriod.name.toUpperCase()),
                timingColor: _timingColor(medicine.timePeriod.name.toUpperCase()),
                formatAmount: _formatAmount,
                filledCount: _filledCountFor(medicine),
                totalCount: _totalCellsFor(medicine),
                complete: _missingCellsFor(medicine).isEmpty,
                onTap: () => _openWizard(medicine),
              ),
            ),
        ],
      ),
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
