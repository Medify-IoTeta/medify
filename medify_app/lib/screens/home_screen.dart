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
import 'intake_history_screen.dart';
import 'settings_screen.dart';
import 'demo_screen.dart'; // DEMO-ONLY: remove after exhibition

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final List<Medicine> _medicines = [];
  bool _polling = true;

  /// Raw backend intake status per timing window (e.g. 'MISSED', 'POSTPONED', 'APPROVED') — kept
  /// separately from MedicationStatus because that enum collapses several backend statuses into
  /// "pending" for card display, but the Take Now action needs the real status to decide whether
  /// to show/enable itself and which intake id to act on.
  final Map<String, String> _rawStatusByTiming = {};
  final Map<String, int> _intakeIdByTiming = {};
  /// Each timing's Intake.scheduledTime, parsed from the backend — the real ingredient (together
  /// with _earlyWindowMinutes) for deciding whether a PENDING window is inside its Early Window.
  /// Never guessed from local UI state.
  final Map<String, DateTime> _scheduledTimeByTiming = {};
  /// Still-unresolved intakes carried over from a previous day — kept entirely separate from
  /// today's per-timing maps above so one can never overwrite the other, even when both exist for
  /// the same timing at once (e.g. yesterday's EVENING is still unresolved and today's own EVENING
  /// intake has already been created too).
  List<Map<String, dynamic>> _previousDaysUnresolved = [];
  int _earlyWindowMinutes = 60;
  bool _takeNowInFlight = false;
  /// Re-entrancy guard for _refreshIntakeStatuses — it's now called from several places that can
  /// fire close together (the 3s poll tick, notification handlers, postpone actions, the
  /// post-Take-Now watcher) and must never overlap itself.
  bool _refreshingIntakes = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEarlyWindowMinutes();
    _loadMedicines();
    _startPolling();
    _registerFcmToken();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The 3s poll's Future.delayed chain can be throttled or suspended entirely while
      // backgrounded (both Android and iOS impose this) — force an immediate refresh on return
      // rather than waiting for whatever's left of the current delay to elapse.
      _refreshIntakeStatuses();
    }
  }

  Future<void> _loadEarlyWindowMinutes() async {
    try {
      final settings = await _apiService.getIntakeSettings();
      final minutes = int.tryParse(settings['earlyWindowMinutes'] ?? '60') ?? 60;
      if (!mounted) return;
      setState(() => _earlyWindowMinutes = minutes);
    } catch (e) {
      AppLogger.warning('Failed to load earlyWindowMinutes, defaulting to 60: $e', 'Home');
    }
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
      final todayIntakes = results[1] as TodayIntakes;

      // One intake per timing window — last one wins if there's ever more than one. Only today's
      // own intakes populate these maps now; previous-day carry-overs live in
      // _previousDaysUnresolved instead, so they can never overwrite today's own window.
      final statusByTiming = <String, String>{};
      final idByTiming = <String, int>{};
      final scheduledTimeByTiming = <String, DateTime>{};
      for (final intake in todayIntakes.today) {
        final timing = (intake['timing'] as String?)?.toUpperCase();
        final status = intake['status'] as String?;
        final rawId = intake['id'];
        if (timing != null && status != null) statusByTiming[timing] = status;
        if (timing != null && rawId != null) {
          idByTiming[timing] = rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? -1;
        }
        final scheduledTime = parseBackendDateTime(intake['scheduledTime']);
        if (timing != null && scheduledTime != null) scheduledTimeByTiming[timing] = scheduledTime;
      }

      if (!mounted) return;
      setState(() {
        _rawStatusByTiming
          ..clear()
          ..addAll(statusByTiming);
        _intakeIdByTiming
          ..clear()
          ..addAll(idByTiming);
        _scheduledTimeByTiming
          ..clear()
          ..addAll(scheduledTimeByTiming);
        _previousDaysUnresolved = todayIntakes.previousDaysUnresolved;
        _medicines.addAll(medicines.map((m) {
          final mapped = _mapIntakeStatus(statusByTiming[m.timePeriod.name.toUpperCase()]);
          return mapped != null ? m.copyWith(status: mapped) : m;
        }));
      });
    } catch (e) {
      AppLogger.error('Failed to load medicines', e, 'Home');
    }
  }

  /// Refreshes intake state without touching the already-loaded medicine list. Called from several
  /// places that can fire close together — the 3s poll tick, notification handlers, postpone
  /// actions, lifecycle resume, the post-Take-Now watcher — so it guards against overlapping
  /// itself: if a call is already in flight, a concurrent call is a no-op (the next tick, or
  /// whichever trigger fires next, will pick up current state anyway).
  Future<void> _refreshIntakeStatuses() async {
    if (_refreshingIntakes) return;
    _refreshingIntakes = true;
    try {
      final todayIntakes = await _apiService.getTodayIntakes();
      final statusByTiming = <String, String>{};
      final idByTiming = <String, int>{};
      final scheduledTimeByTiming = <String, DateTime>{};
      for (final intake in todayIntakes.today) {
        final timing = (intake['timing'] as String?)?.toUpperCase();
        final status = intake['status'] as String?;
        final rawId = intake['id'];
        if (timing != null && status != null) statusByTiming[timing] = status;
        if (timing != null && rawId != null) {
          idByTiming[timing] = rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? -1;
        }
        final scheduledTime = parseBackendDateTime(intake['scheduledTime']);
        if (timing != null && scheduledTime != null) scheduledTimeByTiming[timing] = scheduledTime;
      }
      if (!mounted) return;
      setState(() {
        _rawStatusByTiming
          ..clear()
          ..addAll(statusByTiming);
        _intakeIdByTiming
          ..clear()
          ..addAll(idByTiming);
        _scheduledTimeByTiming
          ..clear()
          ..addAll(scheduledTimeByTiming);
        _previousDaysUnresolved = todayIntakes.previousDaysUnresolved;
        for (int i = 0; i < _medicines.length; i++) {
          final m = _medicines[i];
          final mapped = _mapIntakeStatus(statusByTiming[m.timePeriod.name.toUpperCase()]);
          _medicines[i] = m.copyWith(status: mapped ?? MedicationStatus.pending);
        }
      });
    } catch (e) {
      AppLogger.warning('Failed to refresh intake statuses: $e', 'Home');
    } finally {
      _refreshingIntakes = false;
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
    WidgetsBinding.instance.removeObserver(this);
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

  String get _formattedDate => _formatDate(DateTime.now());

  /// Shared with previous-day cards, so a carried-over intake's original date reads in the same
  /// format as the header's "today" date.
  String _formatDate(DateTime dt) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
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

  Future<void> _goToHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const IntakeHistoryScreen()),
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

      // Unconditional per-tick refresh — the notification-drain above only surfaces specific
      // queued event types (BUTTON_PRESSED, BLOCKED_REMINDER, reminders); it's not a general
      // "intake state changed" signal. This is what makes DISPENSING/DISPENSED/TAKEN visible
      // within one poll interval regardless of what caused the transition (physical button, a
      // different client, the device's own dispensed/intake_confirmed events) rather than only
      // when this client happens to be the one that triggered it. Safe to call every tick even
      // when one of the branches above already called it — _refreshIntakeStatuses guards against
      // overlapping itself.
      if (_polling && mounted) {
        await _refreshIntakeStatuses();
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
  Future<void> _performTakeNow({int? intakeId, String? timingHint, bool isPreviousDay = false}) async {
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

        // Previous-day cards mutate their own entry in _previousDaysUnresolved, never
        // _medicines/_setWindowStatus — today's own intake for the same timing can exist
        // simultaneously (e.g. yesterday's EVENING still unresolved alongside today's own EVENING),
        // and _setWindowStatus would otherwise wrongly touch today's medicines too.
        if (isPreviousDay) {
          _setPreviousDayCardStatus(startedId, 'DISPENSING');
        } else {
          _setWindowStatus(startedTiming, MedicationStatus.dispensing);
        }

        final finalStatus = startedId != null ? await _pollIntakeUntilTaken(startedId, startedTiming) : null;
        if (finalStatus == 'TAKEN') {
          if (isPreviousDay) {
            _removePreviousDayCard(startedId);
          } else {
            _setWindowStatus(startedTiming, MedicationStatus.taken);
          }
          _showResultSnack('Pills dispensed — intake recorded', success: true);
        } else {
          // Still DISPENSED (or unknown) when we stopped watching — no timeout or failure state
          // here by design. It'll show as taken once the IR sensor confirms.
          if (isPreviousDay) {
            _setPreviousDayCardStatus(startedId, 'DISPENSED');
          } else {
            _setWindowStatus(startedTiming, MedicationStatus.dispensed);
          }
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

  int? _intakeMapId(Map<String, dynamic> intake) {
    final id = intake['id'];
    return id is num ? id.toInt() : int.tryParse('$id');
  }

  /// Optimistic local update to one previous-day card while its take-now is in flight — the next
  /// backend refresh will confirm it, same as _setWindowStatus does for today's medicines.
  void _setPreviousDayCardStatus(int? intakeId, String status) {
    if (!mounted || intakeId == null) return;
    setState(() {
      final idx = _previousDaysUnresolved.indexWhere((i) => _intakeMapId(i) == intakeId);
      if (idx != -1) {
        _previousDaysUnresolved[idx] = {..._previousDaysUnresolved[idx], 'status': status};
      }
    });
  }

  /// Drops a previous-day card the moment it's confirmed TAKEN, rather than waiting for the next
  /// poll tick — the backend will also simply stop returning it from then on.
  void _removePreviousDayCard(int? intakeId) {
    if (!mounted || intakeId == null) return;
    setState(() {
      _previousDaysUnresolved.removeWhere((i) => _intakeMapId(i) == intakeId);
    });
  }

  /// Polls every 3s for up to ~2 minutes, same interval as the notification poll. Updates the UI
  /// to DISPENSED as soon as that's observed — not only once the loop finishes — so a slow or
  /// missing IR confirmation doesn't leave the window stuck showing "Dispensing…" for the full
  /// budget when the backend already recorded DISPENSED seconds in. Gives up silently rather than
  /// surfacing a timeout error — DISPENSED with no confirmation yet is a valid, expected state,
  /// not a failure.
  Future<String?> _pollIntakeUntilTaken(int intakeId, String? timing) async {
    const maxAttempts = 40;
    String? lastStatus;
    bool shownDispensed = false;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return lastStatus;
      try {
        final intake = await _apiService.getIntake(intakeId);
        lastStatus = intake?['status'] as String?;
        if (lastStatus == 'TAKEN') return lastStatus;
        if (lastStatus == 'DISPENSED' && !shownDispensed) {
          shownDispensed = true;
          _setWindowStatus(timing, MedicationStatus.dispensed);
        }
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
        onHistory: _goToHistory,
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
      children: [
        // Previous days section only renders while there's still something unresolved in it —
        // once the last carried-over intake resolves, this simply stops appearing (the backend
        // stops returning it, same mechanism that already drives everything else here).
        if (_previousDaysUnresolved.isNotEmpty) ..._buildPreviousDaysSection(),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text('Today', style: AppTextStyles.h3),
        ),
        // Today's 3 windows always render independently of Previous days — a previous-day intake
        // never replaces or hides today's own window for the same timing.
        ...groups.map((e) => _buildTimingGroup(e.key, e.value)),
      ],
    );
  }

  List<Widget> _buildPreviousDaysSection() {
    // Oldest-first, matching the backend's own ordering (IntakeService.getToday) — no client-side
    // re-sort needed.
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text('Previous days', style: AppTextStyles.h3),
      ),
      ..._previousDaysUnresolved.map(_buildPreviousDayCard),
      const SizedBox(height: AppSpacing.xxl),
    ];
  }

  /// One still-unresolved intake carried over from an earlier day. Deliberately not built from
  /// _medicines/the per-timing maps (those represent today's own windows only) — this renders
  /// straight off the raw intake map, including its own original date, since a previous-day card
  /// and today's card for the same timing can exist and be shown at the same time.
  Widget _buildPreviousDayCard(Map<String, dynamic> intake) {
    final timing = (intake['timing'] as String?)?.toUpperCase() ?? '';
    final status = intake['status'] as String?;
    final intakeId = _intakeMapId(intake);
    final scheduledTime = parseBackendDateTime(intake['scheduledTime']);
    final color = _timingColor(timing);
    final label = timing.isEmpty ? '' : timing[0] + timing.substring(1).toLowerCase();
    final cardStatus = _mapIntakeStatus(status) ?? MedicationStatus.pending;
    final meds = _medicinesForTiming(timing);

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
          title: Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.bodyLg)),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(status: cardStatus),
            ],
          ),
          // The original date — the whole reason this section exists separately from Today, so
          // the user can tell this isn't today's own window.
          subtitle: scheduledTime != null
              ? Text(_formatDate(scheduledTime), style: AppTextStyles.bodySm)
              : null,
          children: [
            const Divider(height: 1),
            ...meds.map((m) => MedicationCard(medicine: m)),
            _buildIntakeAction(
              status: status,
              intakeId: intakeId,
              timing: timing,
              alwaysEligibleIfPending: true,
              isPreviousDay: true,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingGroup(String timing, List<Medicine> meds) {
    final taken = meds.where((m) => m.status == MedicationStatus.taken).length;
    final color = _timingColor(timing);
    final label = timing[0] + timing.substring(1).toLowerCase();
    // The intake status belongs to the window, not to each medication — all medicines in a timing
    // window share one intake, so this reads it once here instead of once per medication card.
    final windowStatus = _mapIntakeStatus(_rawStatusByTiming[timing]) ?? MedicationStatus.pending;

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
          title: Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.bodyLg)),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(status: windowStatus),
            ],
          ),
          subtitle: Text('$taken / ${meds.length} taken',
              style: AppTextStyles.bodySm),
          children: [
            const Divider(height: 1),
            ...meds.map((m) => MedicationCard(medicine: m)),
            _buildIntakeAction(
              status: _rawStatusByTiming[timing],
              intakeId: _intakeIdByTiming[timing],
              timing: timing,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  /// Status-driven action row, shared by today's windows and previous-day cards, backed by the
  /// real backend status (not the collapsed MedicationStatus). "Take now" shows for MISSED,
  /// POSTPONED, or a PENDING window that's actually inside its Early Window right now (checked
  /// against the real scheduledTime + earlyWindowMinutes, not guessed) — never for APPROVED, and
  /// never for a PENDING window before its Early Window opens. [alwaysEligibleIfPending] skips that
  /// Early Window check entirely — used for previous-day cards, which are by definition already
  /// past their original window and must never be blocked by a restriction that only makes sense
  /// for a window that hasn't opened yet today. This is presentation-only: the backend's take-now
  /// endpoint remains the real eligibility check regardless of what this shows.
  Widget _buildIntakeAction({
    required String? status,
    required int? intakeId,
    required String timing,
    bool alwaysEligibleIfPending = false,
    bool isPreviousDay = false,
  }) {
    if (status == null) return const SizedBox.shrink();

    final showTakeNow = status == 'MISSED' ||
        status == 'POSTPONED' ||
        (status == 'PENDING' &&
            (alwaysEligibleIfPending || _isPendingWithinEarlyWindow(timing)));

    if (showTakeNow) {
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
                : () => _performTakeNow(
                      intakeId: intakeId,
                      timingHint: timing,
                      isPreviousDay: isPreviousDay,
                    ),
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

  /// now >= scheduledTime - earlyWindowMinutes AND now < scheduledTime, using the real
  /// Intake.scheduledTime from the backend and the real configured earlyWindowMinutes — never
  /// guessed from local state. Once scheduledTime itself arrives, this intentionally returns false:
  /// the normal reminder dialog (or, later, the MISSED sweep) is what surfaces the action from then on.
  bool _isPendingWithinEarlyWindow(String timing) {
    final scheduledTime = _scheduledTimeByTiming[timing];
    if (scheduledTime == null) return false;
    final now = DateTime.now();
    final earlyWindowStart = scheduledTime.subtract(Duration(minutes: _earlyWindowMinutes));
    return !now.isBefore(earlyWindowStart) && now.isBefore(scheduledTime);
  }
}
