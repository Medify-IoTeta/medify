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
import 'demo_screen.dart'; // DEMO-ONLY: remove after exhibition

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final List<Medicine> _medicines = [];
  bool _polling = true;

  /// Raw backend intake status per timing window (e.g. 'MISSED', 'POSTPONED', 'APPROVED') — kept
  /// separately from MedicationStatus because that enum collapses several backend statuses into
  /// "pending" for card display, but the Take Now action needs the real status to decide whether
  /// to show/enable itself and which intake id to act on.
  final Map<String, String> _rawStatusByTiming = {};
  final Map<String, int> _intakeIdByTiming = {};
  bool _takeNowInFlight = false;

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

      // One intake per timing window — last one wins if there's ever more than one.
      final statusByTiming = <String, String>{};
      final idByTiming = <String, int>{};
      for (final intake in intakes) {
        final timing = (intake['timing'] as String?)?.toUpperCase();
        final status = intake['status'] as String?;
        final rawId = intake['id'];
        if (timing != null && status != null) statusByTiming[timing] = status;
        if (timing != null && rawId != null) {
          idByTiming[timing] = rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? -1;
        }
      }

      if (!mounted) return;
      setState(() {
        _rawStatusByTiming
          ..clear()
          ..addAll(statusByTiming);
        _intakeIdByTiming
          ..clear()
          ..addAll(idByTiming);
        _medicines.addAll(medicines.map((m) {
          final mapped = _mapIntakeStatus(statusByTiming[m.timePeriod.name.toUpperCase()]);
          return mapped != null ? m.copyWith(status: mapped) : m;
        }));
      });
    } catch (e) {
      AppLogger.error('Failed to load medicines', e, 'Home');
    }
  }

  /// Refreshes intake state without touching the already-loaded medicine list — used after a
  /// take-now attempt to pick up whatever the backend actually did, rather than assuming.
  Future<void> _refreshIntakeStatuses() async {
    try {
      final intakes = await _apiService.getTodayIntakes();
      final statusByTiming = <String, String>{};
      final idByTiming = <String, int>{};
      for (final intake in intakes) {
        final timing = (intake['timing'] as String?)?.toUpperCase();
        final status = intake['status'] as String?;
        final rawId = intake['id'];
        if (timing != null && status != null) statusByTiming[timing] = status;
        if (timing != null && rawId != null) {
          idByTiming[timing] = rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? -1;
        }
      }
      if (!mounted) return;
      setState(() {
        _rawStatusByTiming
          ..clear()
          ..addAll(statusByTiming);
        _intakeIdByTiming
          ..clear()
          ..addAll(idByTiming);
        for (int i = 0; i < _medicines.length; i++) {
          final m = _medicines[i];
          final mapped = _mapIntakeStatus(statusByTiming[m.timePeriod.name.toUpperCase()]);
          _medicines[i] = m.copyWith(status: mapped ?? MedicationStatus.pending);
        }
      });
    } catch (e) {
      AppLogger.warning('Failed to refresh intake statuses: $e', 'Home');
    }
  }

  MedicationStatus? _mapIntakeStatus(String? intakeStatus) {
    switch (intakeStatus) {
      case 'TAKEN':      return MedicationStatus.taken;
      case 'DISPENSING': return MedicationStatus.dispensing;
      case 'DISPENSED':  return MedicationStatus.dispensed;
      case 'MISSED':     return MedicationStatus.missed;
      case 'INCOMPLETE': return MedicationStatus.incomplete;
      case 'POSTPONED':  return MedicationStatus.postponed;
      default:           return null; // PENDING/APPROVED -> leave the medicine's own default (pending)
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
      MaterialPageRoute(
        builder: (context) => DemoScreen(onReset: _apiService.resetDemoIntake),
      ),
    );
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
            // The backend has already decided what to do about the button press by this point
            // (see IntakeOrchestrationService/DeviceWebSocketHandler) — the button dispenses on
            // its own even if this app is closed. This is purely informational: show what
            // happened and refresh so the UI reflects it.
            final message = result['message'] as String? ?? 'Physical button pressed.';
            _showResultSnack(message, success: (result['outcome'] as String?) == 'STARTED');
            await _refreshIntakeStatuses();
          } else if (type == 'BLOCKED_REMINDER') {
            // The backend withheld this dose's normal reminder because an earlier dose is still
            // unresolved (see ReminderScheduler.maybeSendScheduledReminder) — this must never be
            // shown as the normal actionable reminder dialog, since this dose isn't actually
            // available yet. Purely informational.
            final message = result['message'] as String? ?? 'A previous dose needs attention first.';
            _showResultSnack(message, success: false);
            await _refreshIntakeStatuses();
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
                  if (picked != null && intakeId != null) {
                    final formatted =
                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    await _apiService.postponeIntake(intakeId, until: formatted);
                    await _refreshIntakeStatuses();
                  }
                },
                child: const Text('Choose Time'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (intakeId != null) {
                    await _apiService.postponeIntake(intakeId, minutes: 15);
                    await _refreshIntakeStatuses();
                  }
                },
                child: const Text('Remind in 15 min'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _performTakeNow(intakeId: intakeId, timingHint: timing);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The one action behind starting/continuing an intake from the app — MISSED/POSTPONED "Take
  /// now" buttons, the reminder dialog's OK, and a proactive early-window take-now all funnel
  /// through this. It never decides eligibility itself: the backend's shared
  /// IntakeOrchestrationService does, and this just renders whatever outcome comes back.
  Future<void> _performTakeNow({int? intakeId, String? timingHint}) async {
    if (_takeNowInFlight) return; // guards against double-tap; the backend also protects itself
    setState(() => _takeNowInFlight = true);
    try {
      final result = await _apiService.takeNow(intakeId: intakeId);
      final outcome = result['outcome'] as String?;

      if (outcome == 'STARTED') {
        final startedIntake = result['intake'] as Map<String, dynamic>?;
        final startedTiming = (startedIntake?['timing'] as String?) ?? timingHint;
        final rawId = startedIntake?['id'];
        final startedId = rawId is num ? rawId.toInt() : (rawId != null ? int.tryParse('$rawId') : null);

        _setWindowStatus(startedTiming, MedicationStatus.dispensing);

        final finalStatus = startedId != null ? await _pollIntakeUntilTaken(startedId) : null;
        if (finalStatus == 'TAKEN') {
          _setWindowStatus(startedTiming, MedicationStatus.taken);
          _showResultSnack('Pills dispensed — intake recorded', success: true);
        } else {
          // Still DISPENSED (or unknown) when we stopped watching — no timeout or failure state
          // here by design. It'll show as taken once the IR sensor confirms.
          _setWindowStatus(startedTiming, MedicationStatus.dispensed);
          _showResultSnack('Dispensed — remove the medication to complete', success: true);
        }
        return;
      }

      // Anything other than STARTED is a normal, expected business outcome (nothing available,
      // blocked by an earlier dose, already in progress, device offline, ...) — not an error.
      await _refreshIntakeStatuses();
      if (!mounted) return;
      await _showTakeNowOutcomeDialog(result);
    } on ApiException catch (e) {
      _showResultSnack(e.message, success: false);
    } catch (e) {
      AppLogger.error('Take now failed', e, 'Home');
      _showResultSnack('Error: $e', success: false);
    } finally {
      if (mounted) setState(() => _takeNowInFlight = false);
    }
  }

  /// Explains a non-STARTED take-now outcome in plain language, and — when it's blocked by an
  /// earlier unresolved dose — offers to act on that dose directly instead of just saying no.
  Future<void> _showTakeNowOutcomeDialog(Map<String, dynamic> result) async {
    final outcome = result['outcome'] as String?;
    final blocking = result['blockingIntake'] as Map<String, dynamic>?;
    final message = result['message'] as String? ?? 'Nothing to do right now.';

    if (outcome == 'NOTHING_AVAILABLE') {
      _showResultSnack(message, success: false);
      return;
    }

    final blockingId = blocking?['id'];
    final blockingIntakeId = blockingId is num ? blockingId.toInt() : null;
    final blockingStatus = blocking?['status'] as String?;
    final canOfferBlockingIntake = outcome == 'BLOCKED_BY_EARLIER_INTAKE' &&
        blockingIntakeId != null &&
        (blockingStatus == 'MISSED' || blockingStatus == 'POSTPONED' ||
            blockingStatus == 'PENDING' || blockingStatus == 'APPROVED');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('One thing first'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (canOfferBlockingIntake)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _performTakeNow(intakeId: blockingIntakeId);
              },
              child: const Text('Take that now'),
            ),
        ],
      ),
    );
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
            _buildWindowAction(timing),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  /// Status-driven action row for a timing window, backed by the real backend status (not the
  /// collapsed MedicationStatus) so MISSED/POSTPONED/PENDING/APPROVED each get a "Take now" while
  /// DISPENSING/DISPENSED get progress/removal messaging instead of a second dispense action.
  Widget _buildWindowAction(String timing) {
    final status = _rawStatusByTiming[timing];
    if (status == null) return const SizedBox.shrink();

    const startable = {'PENDING', 'APPROVED', 'MISSED', 'POSTPONED'};
    if (startable.contains(status)) {
      final label = switch (status) {
        'MISSED' => 'Take now (missed)',
        'POSTPONED' => 'Take now (postponed)',
        _ => 'Take now',
      };
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _takeNowInFlight
                ? null
                : () => _performTakeNow(intakeId: _intakeIdByTiming[timing], timingHint: timing),
            child: Text(label),
          ),
        ),
      );
    }

    String? info;
    if (status == 'DISPENSED') {
      info = 'Medication is waiting in the compartment — remove it to complete this dose.';
    } else if (status == 'INCOMPLETE') {
      info = 'This dose wasn\'t confirmed taken and may still be in the compartment.';
    } else if (status == 'DISPENSING') {
      info = 'Dispensing…';
    }
    if (info == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Text(info, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
    );
  }
}
