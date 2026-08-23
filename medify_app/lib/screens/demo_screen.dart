// DEMO-ONLY: remove this file after the exhibition
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DemoScreen extends StatefulWidget {
  final Future<void> Function(String timing) onReset;

  const DemoScreen({super.key, required this.onReset});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  static const List<int> _missedWindowPresets = [1, 2, 5, 10, 30, 60];

  final ApiService _apiService = ApiService();
  String? _loadingTiming;

  bool _loadingMissedWindow = true;
  int? _missedWindowMinutes;

  @override
  void initState() {
    super.initState();
    _loadMissedWindow();
  }

  Future<void> _loadMissedWindow() async {
    try {
      final settings = await _apiService.getIntakeSettings();
      final minutes = int.tryParse(settings['missedWindowMinutes'] ?? '60') ?? 60;
      if (!mounted) return;
      setState(() {
        _missedWindowMinutes = minutes;
        _loadingMissedWindow = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMissedWindow = false);
    }
  }

  Future<void> _setMissedWindow(int minutes) async {
    setState(() => _loadingMissedWindow = true);
    try {
      final updated = await _apiService.updateMissedWindowMinutes(minutes);
      if (!mounted) return;
      setState(() {
        _missedWindowMinutes = int.tryParse(updated['missedWindowMinutes'] ?? '$minutes') ?? minutes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('MISSED window set to $minutes min')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Something went wrong.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loadingMissedWindow = false);
    }
  }

  Future<void> _reset(String timing) async {
    setState(() => _loadingTiming = timing);
    try {
      await widget.onReset(timing);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$timing window reset to pending')));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Something went wrong.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loadingTiming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('For Demo Only')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('MISSED window duration', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How long after the scheduled time a dose stays available before becoming '
            'MISSED. Demo/testing only — production default is 60 minutes and is '
            'unaffected unless you change this here.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          _loadingMissedWindow
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _missedWindowPresets.map((minutes) {
                    final selected = minutes == _missedWindowMinutes;
                    return ChoiceChip(
                      label: Text('$minutes min'),
                      selected: selected,
                      onSelected: selected ? null : (_) => _setMissedWindow(minutes),
                    );
                  }).toList(),
                ),

          const SizedBox(height: AppSpacing.xxl),
          Text('Reset a window', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Resets the chosen window back to pending, both here and on the '
            'Home screen, even if it was already taken. This does NOT send a '
            'reminder — use it to get a fresh start before replaying the flow.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          _demoButton('MORNING', 'Morning', Icons.wb_sunny_outlined),
          const SizedBox(height: AppSpacing.sm),
          _demoButton('NOON', 'Noon', Icons.wb_cloudy_outlined),
          const SizedBox(height: AppSpacing.sm),
          _demoButton('EVENING', 'Evening', Icons.nights_stay_outlined),
        ],
      ),
    );
  }

  Widget _demoButton(String timing, String label, IconData icon) {
    final loading = _loadingTiming == timing;
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _loadingTiming == null ? () => _reset(timing) : null,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}
