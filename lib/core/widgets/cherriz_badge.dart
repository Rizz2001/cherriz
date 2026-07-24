import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum CherrizBadgeVariant { success, warning, danger, info, neutral }

class CherrizBadge extends StatelessWidget {
  final String text;
  final CherrizBadgeVariant variant;
  final IconData? icon;

  const CherrizBadge({
    super.key,
    required this.text,
    this.variant = CherrizBadgeVariant.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (variant) {
      case CherrizBadgeVariant.success:
        backgroundColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        break;
      case CherrizBadgeVariant.warning:
        backgroundColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
        break;
      case CherrizBadgeVariant.danger:
        backgroundColor = AppColors.danger.withValues(alpha: 0.1);
        textColor = AppColors.danger;
        break;
      case CherrizBadgeVariant.info:
        backgroundColor = AppColors.info.withValues(alpha: 0.1);
        textColor = AppColors.info;
        break;
      case CherrizBadgeVariant.neutral:
        backgroundColor = AppColors.border;
        textColor = AppColors.textHigh;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
