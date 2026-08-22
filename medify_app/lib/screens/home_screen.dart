import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/medication_card.dart';
import '../widgets/progress_ring.dart';
import 'register_screen.dart';
import 'edit_medicines_screen.dart';
import 'fill_box_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final List<Medicine> _medicines = [];
  bool _polling = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _startPolling();
    _registerFcmToken();
  }

  Future<void> _registerFcmToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _apiService.registerFcmToken(token);
      }
    } catch (e) {
      AppLogger.error('FCM token registration failed', e, 'Home');
    }
  }

  Future<void> _loadMedicines() async {
    try {
      final results = await Future.wait([
        _apiService.getMedicines(),
        _apiService.getTodayIntakes(),
      ]);
      final medicines = results[0] as List<Medicine>;
      final intakes   = results[1] as List<Map<String, dynamic>>;

      final takenTimings = intakes
          .where((i) => i['status'] == 'TAKEN')
          .map((i) => (i['timing'] as String).toUpperCase())
          .toSet();

      if (!mounted) return;
      setState(() {
        _medicines.addAll(medicines.map((m) {
          final inTaken = takenTimings.contains(m.timePeriod.name.toUpperCase());
          return inTaken ? m.copyWith(status: MedicationStatus.taken) : m;
        }));
      });
    } catch (e) {
      AppLogger.error('Failed to load medicines', e, 'Home');
    }
  }

  @override
  void dispose() {
    _polling = false;
    super.dispose();
  }

  // ── Computed ─────────────────────────────────────────────────

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _formattedDate {
    final now = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  List<Medicine> get _upcoming =>
      _medicines.where((m) => m.status == MedicationStatus.pending && m.enabled).toList();

  List<Medicine> get _completed =>
      _medicines.where((m) => m.status == MedicationStatus.taken).toList();

  int get _takenCount => _completed.length;

  bool _isScheduled(Medicine m) =>
      m.enabled &&
      (m.disabledUntil == null || m.disabledUntil!.isBefore(DateTime.now()));

  List<Medicine> _medicinesForTiming(String timing) => _medicines
      .where((m) => m.timePeriod.name.toUpperCase() == timing && _isScheduled(m))
      .toList();

  IconData _timingIcon(String timing) {
    switch (timing) {
      case 'MORNING': return Icons.wb_twilight;
      case 'NOON':    return Icons.wb_sunny_outlined;
      case 'EVENING': return Icons.nights_stay_outlined;
      default:        return Icons.schedule;
    }
  }

  Color _timingColor(String timing) {
    switch (timing) {
      case 'MORNING': return const Color(0xFFF59F0A);
      case 'NOON':    return AppColors.primary;
      case 'EVENING': return const Color(0xFF7C6EF8);
      default:        return AppColors.textSecondary;
    }
  }

  int get _totalEnabled => _medicines.where((m) => m.enabled).length;

  List<String> get _activeTimings => ['MORNING', 'NOON', 'EVENING']
      .where((t) => _medicinesForTiming(t).isNotEmpty)
      .toList();

  int get _totalWindows => _activeTimings.length;

  int get _completedWindows => _activeTimings
      .where((t) => _medicinesForTiming(t)
          .every((m) => m.status == MedicationStatus.taken))
      .length;

  String get _subtitle {
    if (_totalWindows == 0) return 'No medicines registered';
    if (_completedWindows == _totalWindows) return 'All done for today';
    final remaining = _totalWindows - _completedWindows;
    return '$remaining window${remaining == 1 ? '' : 's'} remaining';
  }

  // ── Navigation ───────────────────────────────────────────────

  Future<void> _goToRegister() async {
    final Medicine? newMedicine = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
    if (newMedicine != null) {
      setState(() => _medicines.add(newMedicine));
    }
  }

  Future<void> _goToFillGuide() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FillBoxGuideScreen()),
    );
  }

  Future<void> _goToEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditMedicinesScreen()),
    );
    // Reload medicines after editing (deletions/disables may have changed state)
    setState(() => _medicines.clear());
    _loadMedicines();
  }

  // ── Polling ──────────────────────────────────────────────────

  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!_polling || !mounted) return false;

      try {
        final result = await _apiService.getNotification();
        if (result['status'] == 'OK') {
          final message  = result['message']  as String;
          final intakeId = result['intakeId'] as int?;
          final timing   = result['timing']   as String?;
          if (!mounted) return false;
          await _showReminderDialog(message, intakeId, timing);
        }
      } catch (e) {
        AppLogger.warning('Notification poll failed, retrying: $e', 'Home');
      }

      return _polling && mounted;
    });
  }

  Future<void> _showReminderDialog(String message, int? intakeId, String? timing) async {
    final timingMeds = timing != null ? _medicinesForTiming(timing) : <Medicine>[];

    await showDialog(
      context: context,
      builder: (_) {
        bool expanded = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Reminder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (timingMeds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setDialogState(() => expanded = !expanded),
                    child: Row(
                      children: [
                        Text(
                          expanded ? 'Hide medicines' : 'Show medicines',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 6),
                    ...timingMeds.map((m) => Padding(
                          padding: const EdgeInsets.only(left: 4, top: 2),
                          child: Text(
                            '• ${m.name}  ${_formatAmount(m.dosageAmount)} ${m.dosageUnit.name}',
                            style: AppTextStyles.bodySm,
                          ),
                        )),
                  ],
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    if (intakeId != null) {
                      await _apiService.postponeIntake(intakeId);
                    }
                    await _apiService.sendNotification(
                      'snooze_custom:${picked.hour}:${picked.minute}',
                      intakeId: intakeId,
                    );
                  }
                },
                child: const Text('Choose Time'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (intakeId != null) {
                    await _apiService.postponeIntake(intakeId);
                  }
                  await _apiService.sendNotification('snooze_15', intakeId: intakeId);
                },
                child: const Text('Remind in 15 min'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _handleConfirmIntake(intakeId, timing);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleConfirmIntake(int? intakeId, String? timing) async {
    try {
      if (intakeId != null) {
        await _apiService.approveIntake(intakeId);
      }

      final bool dispensed = await _apiService.dispenseFromDevice();

      if (dispensed && intakeId != null) {
        await _apiService.releaseIntake(intakeId);
        setState(() {
          for (int i = 0; i < _medicines.length; i++) {
            final m = _medicines[i];
            final inWindow = timing == null ||
                m.timePeriod.name.toUpperCase() == timing.toUpperCase();
            if (m.status == MedicationStatus.pending && inWindow) {
              _medicines[i] = m.copyWith(status: MedicationStatus.taken);
            }
          }
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(dispensed
            ? 'Pills dispensed — intake recorded'
            : 'Device did not respond as expected'),
        backgroundColor: dispensed ? Colors.green : Colors.orange,
      ));
    } catch (e) {
      AppLogger.error('Intake action failed', e, 'Home');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  String _formatAmount(double amount) =>
      amount == amount.truncateToDouble() ? amount.toInt().toString() : amount.toString();

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medify'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset('assets/medify-logo.png', height: 80),
          ),
        ],
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: AppSidebar(
        onAddMedicine: _goToRegister,
        onEditMedicines: _goToEdit,
        onFillBox: _goToFillGuide,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting, style: AppTextStyles.h2),
                      const SizedBox(height: 4),
                      Text(_formattedDate,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(_subtitle, style: AppTextStyles.bodySm),
                    ],
                  ),
                ),
                ProgressRing(taken: _completedWindows, total: _totalWindows),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            Expanded(child: _buildMedicineList()),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineList() {
    if (_medicines.isEmpty) {
      return Center(
        child: Text('No medicines registered yet', style: AppTextStyles.body),
      );
    }

    const timings = ['MORNING', 'NOON', 'EVENING'];
    final groups = timings
        .map((t) => MapEntry(t, _medicinesForTiming(t)))
        .where((e) => e.value.isNotEmpty)
        .toList();

    return ListView(
      children: groups.map((e) => _buildTimingGroup(e.key, e.value)).toList(),
    );
  }

  Widget _buildTimingGroup(String timing, List<Medicine> meds) {
    final taken = meds.where((m) => m.status == MedicationStatus.taken).length;
    final color = _timingColor(timing);
    final label = timing[0] + timing.substring(1).toLowerCase();

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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdBorder,
            ),
            child: Icon(_timingIcon(timing), color: color, size: 20),
          ),
          title: Text(label, style: AppTextStyles.bodyLg),
          subtitle: Text('$taken / ${meds.length} taken',
              style: AppTextStyles.bodySm),
          children: [
            const Divider(height: 1),
            ...meds.map((m) => MedicationCard(medicine: m)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
