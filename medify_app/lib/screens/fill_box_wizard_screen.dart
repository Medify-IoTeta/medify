import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Elderly-friendly step-through wizard: walks the user through the
/// physical cells one medicine's pills belong in, one cell at a time.
class FillBoxWizardScreen extends StatefulWidget {
  final Medicine medicine;
  final List<int> cellNumbers; // 0-based, pre-ordered by the caller
  final int currentSlot;
  final bool Function(int slot) isFilled;

  const FillBoxWizardScreen({
    super.key,
    required this.medicine,
    required this.cellNumbers,
    required this.currentSlot,
    required this.isFilled,
  });

  @override
  State<FillBoxWizardScreen> createState() => _FillBoxWizardScreenState();
}

class _FillBoxWizardScreenState extends State<FillBoxWizardScreen> {
  final ApiService _apiService = ApiService();

  late int _index;
  late Set<int> _filledLocal;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _filledLocal = widget.cellNumbers.where(widget.isFilled).toSet();
    final firstUnfilled =
        widget.cellNumbers.indexWhere((s) => !_filledLocal.contains(s));
    _index = firstUnfilled == -1 ? 0 : firstUnfilled;
  }

  int get _currentCell => widget.cellNumbers[_index];
  bool get _currentFilled => _filledLocal.contains(_currentCell);
  bool get _isLast => _index == widget.cellNumbers.length - 1;
  bool get _isNextCycle => _currentCell < widget.currentSlot;

  Future<void> _toggleFilled() async {
    final cell = _currentCell;
    final wasFilled = _filledLocal.contains(cell);
    setState(() {
      _busy = true;
      wasFilled ? _filledLocal.remove(cell) : _filledLocal.add(cell);
    });
    try {
      if (wasFilled) {
        await _apiService.unmarkSlotFilled(cell, widget.medicine.id);
      } else {
        await _apiService.markSlotFilled(cell, widget.medicine.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        wasFilled ? _filledLocal.add(cell) : _filledLocal.remove(cell);
      });
      _showError('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goBack() {
    if (_index == 0) return;
    setState(() => _index--);
  }

  void _goNext() {
    if (!_isLast) {
      setState(() => _index++);
      return;
    }
    final allFilled = widget.cellNumbers.every(_filledLocal.contains);
    if (allFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All cells filled for ${widget.medicine.name}!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
    Navigator.pop(context);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  String _formatAmount(double a) =>
      a == a.truncateToDouble() ? a.toInt().toString() : a.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicine.name, style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text(
                'Cell ${_index + 1} of ${widget.cellNumbers.length}',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentFilled
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('CELL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                )),
                            Text(
                              '${_currentCell + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 88,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        '${_formatAmount(widget.medicine.dosageAmount)} ${widget.medicine.dosageUnit.name} of ${widget.medicine.name}',
                        style: AppTextStyles.h3,
                        textAlign: TextAlign.center,
                      ),
                      if (_isNextCycle) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: AppRadius.mdBorder,
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: Text(
                            'This cell is for your next refill round',
                            style: AppTextStyles.bodyLg
                                .copyWith(color: AppColors.warning),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 68,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _toggleFilled,
                  icon: Icon(
                    _currentFilled
                        ? Icons.check_circle
                        : Icons.add_circle_outline,
                    size: 26,
                  ),
                  label: Text(
                    _currentFilled ? 'Filled — Tap to Undo' : 'Mark as Filled',
                    style: AppTextStyles.h3.copyWith(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _currentFilled ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 68,
                      child: OutlinedButton.icon(
                        onPressed: _index == 0 ? null : _goBack,
                        icon: const Icon(Icons.arrow_back, size: 24),
                        label: Text('Back', style: AppTextStyles.h3),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SizedBox(
                      height: 68,
                      child: ElevatedButton.icon(
                        onPressed: _goNext,
                        icon: Icon(
                          _isLast ? Icons.check : Icons.arrow_forward,
                          size: 24,
                        ),
                        label: Text(
                          _isLast ? 'Done' : 'Next',
                          style: AppTextStyles.h3.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
