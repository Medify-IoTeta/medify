import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProgressRing extends StatelessWidget {
  final int taken;
  final int total;

  const ProgressRing({
    super.key,
    required this.taken,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = total == 0 ? 0.0 : taken / total;

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 8,
            backgroundColor: AppColors.muted,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$taken/$total',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'doses taken',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
