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
  String? _loadingTiming;

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
