import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'cherriz_button.dart';

class CherrizModal {
  CherrizModal._();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  content,
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (cancelText != null)
                        CherrizButton(
                          text: cancelText,
                          variant: CherrizButtonVariant.ghost,
                          onPressed: onCancel ?? () => Navigator.pop(dialogContext),
                        ),
                      if (confirmText != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        CherrizButton(
                          text: confirmText,
                          variant: isDestructive
                              ? CherrizButtonVariant.destructive
                              : CherrizButtonVariant.primary,
                          onPressed: onConfirm,
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
