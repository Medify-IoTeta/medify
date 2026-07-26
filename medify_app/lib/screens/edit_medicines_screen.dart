import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

// ── List screen ───────────────────────────────────────────────

class EditMedicinesScreen extends StatefulWidget {
  const EditMedicinesScreen({super.key});

  @override
  State<EditMedicinesScreen> createState() => _EditMedicinesScreenState();
}

class _EditMedicinesScreenState extends State<EditMedicinesScreen> {
  final ApiService _apiService = ApiService();
  List<Medicine> _medicines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final medicines = await _apiService.getMedicines();
      if (!mounted) return;
      setState(() {
        _medicines = medicines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load medicines: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  String _timingTime(TimePeriod t) {
    switch (t) {
      case TimePeriod.morning: return '08:00';
      case TimePeriod.noon:    return '13:00';
      case TimePeriod.evening: return '20:00';
      default:                 return '';
    }
  }

  String _dosageText(Medicine m) {
    final amt = m.dosageAmount == m.dosageAmount.truncateToDouble()
        ? m.dosageAmount.toInt().toString()
        : m.dosageAmount.toString();
    final unit = m.dosageUnit.name[0].toUpperCase() + m.dosageUnit.name.substring(1);
    final time = _timingTime(m.timePeriod);
    return '$amt $unit · $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Medicines'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset('assets/medify-logo.png', height: 40),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _medicines.isEmpty
              ? Center(child: Text('No medicines registered', style: AppTextStyles.body))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _medicines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final medicine = _medicines[i];
                    return InkWell(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditMedicineDetailScreen(medicine: medicine),
                          ),
                        );
                        if (result is Medicine) {
                          setState(() {
                            final idx = _medicines.indexWhere((m) => m.id == medicine.id);
                            if (idx != -1) _medicines[idx] = result;
                          });
                        } else if (result == 'deleted') {
                          setState(() => _medicines.removeWhere((m) => m.id == medicine.id));
                        }
                      },
                      borderRadius: AppRadius.lgBorder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.lgBorder,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.medication_outlined,
                                color: AppColors.primary, size: 28),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(medicine.name, style: AppTextStyles.bodyLg),
                                  Text(_dosageText(medicine), style: AppTextStyles.bodySm),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ── Detail / edit screen ──────────────────────────────────────

class EditMedicineDetailScreen extends StatefulWidget {
  final Medicine medicine;
  const EditMedicineDetailScreen({super.key, required this.medicine});

  @override
  State<EditMedicineDetailScreen> createState() => _EditMedicineDetailScreenState();
}

class _EditMedicineDetailScreenState extends State<EditMedicineDetailScreen> {
  final ApiService _apiService = ApiService();

  late TextEditingController _amountController;
  late DosageUnit _unit;
  late TimePeriod _timePeriod;
  late bool _active;
  DateTime? _disabledUntil;
  bool _saving = false;

  static const _scheduledTimings = [TimePeriod.morning, TimePeriod.noon, TimePeriod.evening];

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _amountController = TextEditingController(
      text: m.dosageAmount == m.dosageAmount.truncateToDouble()
          ? m.dosageAmount.toInt().toString()
          : m.dosageAmount.toString(),
    );
    _unit = m.dosageUnit;
    _timePeriod = _scheduledTimings.contains(m.timePeriod) ? m.timePeriod : TimePeriod.morning;
    _active = m.enabled;
    final until = m.disabledUntil;
    _disabledUntil = (until != null && until.isAfter(DateTime.now())) ? until : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await _apiService.updateMedicine(
        widget.medicine.id,
        dosageAmount: double.tryParse(_amountController.text) ?? widget.medicine.dosageAmount,
        dosageUnit: _unit.name,
        timing: _timePeriod.name.toUpperCase(),
        active: _active,
        disabledUntil: _disabledUntil,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Delete "${widget.medicine.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _apiService.deleteMedicine(widget.medicine.id);
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _pickDisableUntil() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _disabledUntil ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      _disabledUntil = DateTime(date.year, date.month, date.day, 23, 59, 59);
    });
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _timingLabel(TimePeriod t) {
    switch (t) {
      case TimePeriod.morning: return 'Morning';
      case TimePeriod.noon:    return 'Noon';
      case TimePeriod.evening: return 'Evening';
      default:                 return t.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Medicine'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset('assets/medify-logo.png', height: 40),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Header ───────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppRadius.mdBorder,
                ),
                child: const Icon(Icons.medication_outlined,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(widget.medicine.name, style: AppTextStyles.h3),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Dosage ───────────────────────────────────────────
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
              Expanded(
                child: _Dropdown<DosageUnit>(
                  value: _unit,
                  items: DosageUnit.values,
                  label: (e) => e.name[0].toUpperCase() + e.name.substring(1),
                  onChanged: (v) => setState(() => _unit = v),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Schedule Time ─────────────────────────────────────
          Text('Schedule Time', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          _Dropdown<TimePeriod>(
            value: _timePeriod,
            items: _scheduledTimings,
            label: _timingLabel,
            onChanged: (v) => setState(() => _timePeriod = v),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Include in schedule ───────────────────────────────
          _SettingCard(
            title: 'Include in schedule',
            subtitle: 'Appears in daily schedule & notifications',
            trailing: Switch(
              value: _active,
              onChanged: (v) => setState(() {
                _active = v;
                if (!v) _disabledUntil = null;
              }),
            ),
          ),

          // ── Disable until ─────────────────────────────────────
          if (_active) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: _pickDisableUntil,
              child: _SettingCard(
                title: 'Disable until a specific date',
                subtitle: _disabledUntil != null
                    ? _formatDate(_disabledUntil!)
                    : 'Not set',
                subtitleColor: _disabledUntil != null ? AppColors.warning : null,
                trailing: _disabledUntil != null
                    ? GestureDetector(
                        onTap: () => setState(() => _disabledUntil = null),
                        child: const Icon(Icons.close, size: 18,
                            color: AppColors.textSecondary),
                      )
                    : const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxxl),

          // ── Save Changes ──────────────────────────────────────
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Changes',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Delete ────────────────────────────────────────────
          Center(
            child: TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.error, size: 18),
              label: const Text('Delete Medication Permanently'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────

class _Dropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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

class _SettingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final Widget trailing;

  const _SettingCard({
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLg),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySm.copyWith(
                    color: subtitleColor ?? AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
