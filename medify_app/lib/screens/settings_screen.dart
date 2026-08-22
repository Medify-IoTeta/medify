import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

class SettingsScreen extends StatefulWidget {
  final bool isPatient;

  const SettingsScreen({super.key, required this.isPatient});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  final _emailController = TextEditingController();

  bool _loading = true;
  Map<String, String> _intakeSettings = {};
  List<Map<String, dynamic>> _caregivers = [];
  bool _addingCaregiver = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _apiService.getIntakeSettings(),
        _apiService.getCaregivers(),
      ]);
      if (!mounted) return;
      setState(() {
        _intakeSettings = results[0] as Map<String, String>;
        _caregivers = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load settings', e, 'Settings');
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e);
    }
  }

  void _showError(Object e) {
    final message = e is ApiException ? e.message : 'Something went wrong.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editTime(String key, String label) async {
    if (!widget.isPatient) return;
    final current = _intakeSettings[key] ?? '08:00';
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    try {
      final updated = await _apiService.updateIntakeSettings(
        morning: key == 'morning' ? formatted : _intakeSettings['morning']!,
        noon: key == 'noon' ? formatted : _intakeSettings['noon']!,
        evening: key == 'evening' ? formatted : _intakeSettings['evening']!,
      );
      if (!mounted) return;
      setState(() => _intakeSettings = updated);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addCaregiver() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _addingCaregiver = true);
    try {
      final caregiver = await _apiService.addCaregiver(email);
      if (!mounted) return;
      setState(() {
        _caregivers = [..._caregivers, caregiver];
        _emailController.clear();
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _addingCaregiver = false);
    }
  }

  Future<void> _removeCaregiver(Map<String, dynamic> caregiver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Caregiver'),
        content: Text(
            'Remove ${caregiver['firstName']} ${caregiver['lastName']} as a caregiver? They will no longer be able to view or manage this pillbox.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _apiService.removeCaregiver(caregiver['id'] as int);
      if (!mounted) return;
      setState(() => _caregivers.removeWhere((c) => c['id'] == caregiver['id']));
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text('Reminder Times', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.isPatient
                        ? 'Set when medication reminders go out each day.'
                        : 'Only the patient can change reminder times.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _timeRow('morning', 'Morning', Icons.wb_sunny_outlined),
                  const SizedBox(height: AppSpacing.sm),
                  _timeRow('noon', 'Noon', Icons.wb_cloudy_outlined),
                  const SizedBox(height: AppSpacing.sm),
                  _timeRow('evening', 'Evening', Icons.nights_stay_outlined),

                  const SizedBox(height: AppSpacing.xxl),
                  Text('Caregivers', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.isPatient
                        ? 'Caregivers can monitor your medication schedule and intake status.'
                        : 'Only the patient can add or remove caregivers.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_caregivers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text('No caregivers added yet.', style: AppTextStyles.body),
                    )
                  else
                    ..._caregivers.map(_caregiverRow),

                  if (widget.isPatient) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Caregiver's email",
                              helperText: 'Must already be registered as a caregiver',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _addingCaregiver ? null : _addCaregiver,
                            child: _addingCaregiver
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _timeRow(String key, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: AppRadius.lgBorder,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppRadius.mdBorder,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTextStyles.bodyLg)),
          Text(_intakeSettings[key] ?? '--:--', style: AppTextStyles.bodyLg),
          if (widget.isPatient) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppColors.primary,
              onPressed: () => _editTime(key, label),
            ),
          ],
        ],
      ),
    );
  }

  Widget _caregiverRow(Map<String, dynamic> caregiver) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: AppRadius.lgBorder,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: AppRadius.mdBorder,
              ),
              child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${caregiver['firstName']} ${caregiver['lastName']}',
                      style: AppTextStyles.bodyLg),
                  Text('${caregiver['email']}', style: AppTextStyles.caption),
                ],
              ),
            ),
            if (widget.isPatient)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.error,
                onPressed: () => _removeCaregiver(caregiver),
              ),
          ],
        ),
      ),
    );
  }
}
