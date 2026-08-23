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
import 'settings_screen.dart';
import 'demo_screen.dart';

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

      // One intake per timing window — if more than one ever exists for the
      // same day (backend doesn't guarantee list order), the highest id
      // (most recently created) wins, not whichever happens to come last.
      final latestByTiming = <String, Map<String, dynamic>>{};
      for (final intake in intakes) {
        final timing = (intake['timing'] as String?)?.toUpperCase();
        if (timing == null) continue;
        final id = intake['id'];
        final currentId = latestByTiming[timing]?['id'];
        if (currentId == null || (id is num && currentId is num && id > currentId)) {
          latestByTiming[timing] = intake;
        }
      }
      final statusByTiming = <String, String>{
        for (final entry in latestByTiming.entries)
          if (entry.value['status'] != null) entry.key: entry.value['status'] as String,
      };

      if (!mounted) return;
      setState(() {
        _medicines.addAll(medicines.map((m) {
          final mapped = _mapIntakeStatus(statusByTiming[m.timePeriod.name.toUpperCase()]);
          return mapped != null ? m.copyWith(status: mapped) : m;
        }));
      });
    } catch (e) {
      AppLogger.error('Failed to load medicines', e, 'Home');
    }
  }

  MedicationStatus? _mapIntakeStatus(String? intakeStatus) {
    switch (intakeStatus) {
      case 'TAKEN':      return MedicationStatus.taken;
      case 'DISPENSING': return MedicationStatus.dispensing;
      case 'DISPENSED':  return MedicationStatus.dispensed;
      case 'MISSED':     return MedicationStatus.missed;
      case 'INCOMPLETE': return MedicationStatus.incomplete;
      default:           return null; // leave the medicine's own default (pending)
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

  Future<void> _goToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen(isPatient: true)),
    );
  }

  // DEMO-ONLY: remove after exhibition
  Future<void> _goToDemo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DemoScreen(onReset: _resetDemoWindow)),
    );
  }

  // DEMO-ONLY: remove after exhibition — forces the window's local status back
  // to pending immediately, bypassing _setWindowStatus's "never regress from
  // taken" guard on purpose, so an already-completed window visually resets
  // instead of staying stuck on "Taken" while the backend intake is reset.
  // Does NOT send a reminder notification — this is a pure reset so the flow
  // can be replayed; firing the actual reminder is a separate step.
  Future<void> _resetDemoWindow(String timing) async {
    if (mounted) {
      setState(() {
        for (int i = 0; i < _medicines.length; i++) {
          final m = _medicines[i];
          if (m.timePeriod.name.toUpperCase() == timing.toUpperCase()) {
            _medicines[i] = m.copyWith(status: MedicationStatus.pending);
          }
        }
      });
    }
    await _apiService.resetDemoIntake(timing);
  }

  // ── Polling ──────────────────────────────────────────────────

  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!_polling || !mounted) return false;

      try {
        final result = await _apiService.getNotification();
        if (result['status'] == 'OK') {
          if (!mounted) return false;
          final type = result['type'] as String?;
          if (type == 'BUTTON_PRESSED') {
            // Backend doesn't pick an intake for a button press — we do, same
            // as we would for any other trigger.
            await _handleButtonPressed();
          } else {
            final message  = result['message']  as String;
            final intakeId = result['intakeId'] as int?;
            final timing   = result['timing']   as String?;
            await _showReminderDialog(message, intakeId, timing);
          }
        }
      } catch (e) {
        AppLogger.warning('Notification poll failed, retrying: $e', 'Home');
      }

      return _polling && mounted;
    });
  }

  Future<void> _handleButtonPressed() async {
    try {
      final intakes = await _apiService.getTodayIntakes();
      final pending = intakes.firstWhere(
        (i) => i['status'] == 'PENDING',
        orElse: () => const <String, dynamic>{},
      );

      if (pending.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Button pressed, but nothing is currently pending'),
        ));
        return;
      }

      final rawId = pending['id'];
      final intakeId = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
      if (intakeId == null) {
        AppLogger.error('Button-pressed intake has no usable id: $pending', null, 'Home');
        _showResultSnack('Button pressed, but the pending intake could not be read', success: false);
        return;
      }

      final timing = pending['timing'] as String?;
      if (!mounted) return;
      await _showReminderDialog(
        'Physical button pressed on the pill box — confirm to dispense',
        intakeId,
        timing,
      );
    } catch (e) {
      AppLogger.error('Failed to resolve intake for button press', e, 'Home');
      _showResultSnack('Button pressed, but something went wrong: $e', success: false);
    }
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

  // Backend, not the app, decides when an intake actually becomes TAKEN — that
  // only happens once the device's IR sensor confirms the compartment is
  // empty. This just triggers the dispense and watches for that to happen.
  Future<void> _handleConfirmIntake(int? intakeId, String? timing) async {
    if (intakeId == null) return;

    try {
      await _apiService.approveIntake(intakeId);
      _setWindowStatus(timing, MedicationStatus.dispensing);

      await _apiService.dispenseIntake(intakeId);

      final finalStatus = await _pollIntakeUntilTaken(intakeId);

      if (finalStatus == 'TAKEN') {
        _setWindowStatus(timing, MedicationStatus.taken);
        _showResultSnack('Pills dispensed — intake recorded', success: true);
      } else {
        // Still DISPENSED (or unknown) when we stopped watching — no timeout
        // or failure state here by design. It'll show as taken once the IR
        // sensor confirms, next time the list refreshes.
        _setWindowStatus(timing, MedicationStatus.dispensed);
        _showResultSnack('Dispensed — remove the medication to complete', success: true);
      }
    } catch (e) {
      _setWindowStatus(timing, MedicationStatus.pending);
      AppLogger.error('Intake action failed', e, 'Home');
      _showResultSnack('Error: $e', success: false);
    }
  }

  void _setWindowStatus(String? timing, MedicationStatus status) {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _medicines.length; i++) {
        final m = _medicines[i];
        final inWindow = timing == null ||
            m.timePeriod.name.toUpperCase() == timing.toUpperCase();
        if (inWindow && m.status != MedicationStatus.taken) {
          _medicines[i] = m.copyWith(status: status);
        }
      }
    });
  }

  /// Polls every 3s for up to ~2 minutes, same interval as the notification
  /// poll. Gives up silently rather than surfacing a timeout error — DISPENSED
  /// with no confirmation yet is a valid, expected state, not a failure.
  Future<String?> _pollIntakeUntilTaken(int intakeId) async {
    const maxAttempts = 40;
    String? lastStatus;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return lastStatus;
      try {
        final intake = await _apiService.getIntake(intakeId);
        lastStatus = intake?['status'] as String?;
        if (lastStatus == 'TAKEN') return lastStatus;
      } catch (e) {
        AppLogger.warning('Intake status poll failed, retrying: $e', 'Home');
      }
    }
    return lastStatus;
  }

  void _showResultSnack(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
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
        onSettings: _goToSettings,
        onDemo: _goToDemo, // DEMO-ONLY: remove after exhibition
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
