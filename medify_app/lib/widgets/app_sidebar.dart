import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSidebar extends StatelessWidget {
  final VoidCallback? onAddMedicine;
  final VoidCallback? onTakeManually;
  final VoidCallback? onEditMedicines;

  const AppSidebar({
    super.key,
    this.onAddMedicine,
    this.onTakeManually,
    this.onEditMedicines,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medication, color: AppColors.primary, size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medify', style: AppTextStyles.h3),
                      Text('Manage your medications', style: AppTextStyles.caption),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),

              _SidebarItem(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () => Navigator.pop(context),
              ),
              _SidebarItem(
                icon: Icons.pan_tool_outlined,
                label: 'Take Medication Manually',
                onTap: () {
                  Navigator.pop(context);
                  onTakeManually?.call();
                },
              ),
              _SidebarItem(
                icon: Icons.add_circle_outline,
                label: 'Add Medicine',
                onTap: () {
                  Navigator.pop(context);
                  onAddMedicine?.call();
                },
              ),
              _SidebarItem(
                icon: Icons.edit_outlined,
                label: 'Edit Medicines',
                onTap: () {
                  Navigator.pop(context);
                  onEditMedicines?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: AppRadius.lgBorder,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppRadius.mdBorder,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(label, style: AppTextStyles.bodyLg),
            ],
          ),
        ),
      ),
    );
  }
}
