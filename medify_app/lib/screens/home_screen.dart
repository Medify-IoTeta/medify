import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/medication_card.dart';
import '../widgets/progress_ring.dart';
import 'register_screen.dart';

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
    _startPolling();
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

  int get _totalEnabled => _medicines.where((m) => m.enabled).length;

  String get _subtitle {
    if (_totalEnabled == 0) return 'No medicines registered';
    if (_upcoming.isEmpty) return 'All done for today';
    return '${_upcoming.length} medication${_upcoming.length == 1 ? '' : 's'} remaining';
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

  // ── Polling ──────────────────────────────────────────────────

  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!_polling || !mounted) return false;

      try {
        final result = await _apiService.getNotification();
        if (result['status'] == 'OK') {
          final message = result['message'];
          if (!mounted) return false;
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Reminder'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) {
                      await _apiService.sendNotification(
                          'snooze_custom:${picked.hour}:${picked.minute}');
                    }
                  },
                  child: const Text('Choose Time'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _apiService.sendNotification('snooze_15');
                  },
                  child: const Text('Remind in 15 min'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _apiService.sendNotification('ok');
                    await _handleDispense();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }

      return _polling && mounted;
    });
  }

  Future<void> _handleDispense() async {
    try {
      final bool success = await _apiService.dispenseFromDevice();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Pills dispensed successfully'
            : 'Device did not respond as expected'),
        backgroundColor: success ? Colors.green : Colors.orange,
      ));
    } catch (e) {
      debugPrint('Device error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to communicate with device: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medify'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: AppSidebar(
        onAddMedicine: _goToRegister,
        onTakeManually: () {},
        onEditMedicines: () {},
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
                ProgressRing(taken: _takenCount, total: _totalEnabled),
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

    return ListView(
      children: [
        if (_upcoming.isNotEmpty) ...[
          Text('Upcoming', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          ..._upcoming.map((m) => MedicationCard(medicine: m)),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (_completed.isNotEmpty) ...[
          Text('Completed', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          ..._completed.map((m) => MedicationCard(medicine: m)),
        ],
      ],
    );
  }

}
