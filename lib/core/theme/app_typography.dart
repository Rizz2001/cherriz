import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 1.2,
    letterSpacing: -0.02,
    fontWeight: FontWeight.w800,
    color: AppColors.textHigh,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    height: 1.3,
    letterSpacing: -0.01,
    fontWeight: FontWeight.w700,
    color: AppColors.textHigh,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: AppColors.textHigh,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textHigh,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textHigh,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.5,
    letterSpacing: 0.01,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );
}
