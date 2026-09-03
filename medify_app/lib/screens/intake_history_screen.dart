import 'package:flutter/material.dart';

import '../models/intake_history_entry.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../widgets/intake_history_list.dart';

/// Shared history screen for both the patient app and the caregiver view — same endpoint, same
/// list widget, so the two never show different data for the same patient.
class IntakeHistoryScreen extends StatefulWidget {
  const IntakeHistoryScreen({super.key});

  @override
  State<IntakeHistoryScreen> createState() => _IntakeHistoryScreenState();
}

class _IntakeHistoryScreenState extends State<IntakeHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<IntakeHistoryEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _apiService.getIntakeHistory(days: 5);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load intake history', e, 'IntakeHistory');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load intake history';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intake History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: AppSpacing.xxxl),
                        Center(
                          child: Text(_error!,
                              style: AppTextStyles.body.copyWith(color: AppColors.error)),
                        ),
                      ],
                    )
                  : IntakeHistoryList(entries: _entries),
            ),
    );
  }
}
