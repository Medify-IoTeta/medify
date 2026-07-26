import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

const int _totalSlots = 13;

class FillBoxGuideScreen extends StatefulWidget {
  const FillBoxGuideScreen({super.key});

  @override
  State<FillBoxGuideScreen> createState() => _FillBoxGuideScreenState();
}

class _FillBoxGuideScreenState extends State<FillBoxGuideScreen> {
  final ApiService _apiService = ApiService();

  bool _loading = true;
  Map<String, dynamic>? _refillState;
  List<Medicine> _medicines = [];

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _toggleFill(int slotIndex) async {
    final filled = List<int>.from(_filledSlots);
    try {
      if (filled.contains(slotIndex)) {
        await _apiService.unmarkSlotFilled(slotIndex);
        filled.remove(slotIndex);
      } else {
        await _apiService.markSlotFilled(slotIndex);
        filled.add(slotIndex);
      }
      setState(() {
        _refillState = Map.of(_refillState!)..['filledSlots'] = filled;
      });
    } catch (e) {
      _showError('$e');
    }
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

  List<Medicine> _medsForTiming(String timing) => _scheduledMedicines
      .where((m) => m.timePeriod.name.toUpperCase() == timing)
      .toList();

  int get _currentSlot =>
      (_refillState?['currentSlot'] as num?)?.toInt() ?? 0;

  List<int> get _filledSlots =>
      ((_refillState?['filledSlots'] as List?)?.cast<int>()) ?? [];

  // Circular order: currentSlot … 12, then 0 … currentSlot-1
  List<int> get _slotDisplayOrder {
    final List<int> order = [];
    for (int i = _currentSlot; i < _totalSlots; i++) order.add(i);
    for (int i = 0; i < _currentSlot; i++) order.add(i);
    return order;
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
            child: Image.asset('assets/medify-logo.png', height: 56),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final timings = _activeTimings;

    if (_refillState == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text('No active refill session.',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: _startNewRefill,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Start First Refill'),
            ),
          ],
        ),
      );
    }

    if (timings.isEmpty) {
      return Center(
        child: Text('No active medicines registered.',
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary)),
      );
    }

    final displayOrder = _slotDisplayOrder;
    final filledCount = _filledSlots.length;

    return Column(
      children: [
        // ── Summary bar ───────────────────────────────────────
        Container(
          width: double.infinity,
          color: AppColors.muted,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Text('$filledCount / $_totalSlots slots filled',
                  style: AppTextStyles.body),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.smBorder,
                  child: LinearProgressIndicator(
                    value: filledCount / _totalSlots,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('${(filledCount / _totalSlots * 100).round()}%',
                  style: AppTextStyles.bodySm),
            ],
          ),
        ),

        // ── Slot list ─────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: displayOrder.length + 1, // +1 for reset button at bottom
            itemBuilder: (_, listIndex) {
              // Last item: reset button
              if (listIndex == displayOrder.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: _startNewRefill,
                      icon: const Icon(Icons.restart_alt,
                          size: 16, color: AppColors.textSecondary),
                      label: const Text('Reset box (start from slot 1)'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        textStyle: AppTextStyles.bodySm,
                      ),
                    ),
                  ),
                );
              }

              final slotIndex = displayOrder[listIndex];
              final timing = timings[slotIndex % timings.length];
              final day = (slotIndex ~/ timings.length) + 1;
              final meds = _medsForTiming(timing);
              final isCurrent = slotIndex == _currentSlot;
              final isNextCycle = slotIndex < _currentSlot;
              final isFilled = _filledSlots.contains(slotIndex);

              // Insert divider before "next cycle" slots begin
              final prevIndex = listIndex > 0 ? displayOrder[listIndex - 1] : -1;
              final showDivider = isNextCycle && (prevIndex >= _currentSlot);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (listIndex > 0)
                    const SizedBox(height: AppSpacing.sm),
                  if (showDivider) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm),
                          child: Text(
                            'Already dispensed — refill for next cycle',
                            style: AppTextStyles.caption,
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  _SlotCard(
                    slotIndex: slotIndex,
                    timing: timing,
                    day: day,
                    medicines: meds,
                    isCurrent: isCurrent,
                    isNextCycle: isNextCycle,
                    isFilled: isFilled,
                    timingLabel: _timingLabel(timing),
                    timingIcon: _timingIcon(timing),
                    timingColor: _timingColor(timing),
                    formatAmount: _formatAmount,
                    onToggleFill: () => _toggleFill(slotIndex),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Slot card ─────────────────────────────────────────────────

class _SlotCard extends StatelessWidget {
  final int slotIndex;
  final String timing;
  final int day;
  final List<Medicine> medicines;
  final bool isCurrent;
  final bool isNextCycle;
  final bool isFilled;
  final String timingLabel;
  final IconData timingIcon;
  final Color timingColor;
  final String Function(double) formatAmount;
  final VoidCallback onToggleFill;

  const _SlotCard({
    required this.slotIndex,
    required this.timing,
    required this.day,
    required this.medicines,
    required this.isCurrent,
    required this.isNextCycle,
    required this.isFilled,
    required this.timingLabel,
    required this.timingIcon,
    required this.timingColor,
    required this.formatAmount,
    required this.onToggleFill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(
          color: isCurrent ? AppColors.primary : AppColors.border,
          width: isCurrent ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Slot number ──────────────────────────────────
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isNextCycle ? AppColors.muted : AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${slotIndex + 1}',
              style: TextStyle(
                color: isNextCycle ? AppColors.textSecondary : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // ── Timing + medicines ───────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(timingIcon, size: 15, color: timingColor),
                    const SizedBox(width: 4),
                    Text(
                      '$timingLabel  ·  Day $day',
                      style: AppTextStyles.bodyLg,
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppRadius.smBorder,
                        ),
                        child: Text(
                          'NEXT',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ...medicines.map((m) => Padding(
                      padding: const EdgeInsets.only(top: 2, left: 2),
                      child: Text(
                        '• ${m.name}  –  ${formatAmount(m.dosageAmount)} ${m.dosageUnit.name}',
                        style: AppTextStyles.bodySm,
                      ),
                    )),
              ],
            ),
          ),

          // ── Fill toggle ──────────────────────────────────
          GestureDetector(
            onTap: onToggleFill,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: isFilled
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppRadius.smBorder,
                border: Border.all(
                  color: isFilled ? AppColors.success : AppColors.warning,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFilled
                        ? Icons.check_circle_outline
                        : Icons.add_circle_outline,
                    size: 14,
                    color: isFilled ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isFilled ? 'Filled' : 'Fill',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isFilled ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
