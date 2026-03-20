// lib/theme/app_colors.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

abstract class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg         = Color(0xFF141416);   // main scaffold
  static const Color bgElevated = Color(0xFF1B1B1F);   // headers, sheets

  // Surfaces
  static const Color surface1 = Color(0xFF222228);  // cards, rows
  static const Color surface2 = Color(0xFF2A2A32);  // inputs, chips
  static const Color surface3 = Color(0xFF32323C);  // active states

  // Borders
  static const Color border      = Color(0x18FFFFFF); // 9% white
  static const Color borderFocus = Color(0x28FFFFFF); // 16% white

  // Text
  static const Color textPrimary   = Color(0xFFF0F0F6);
  static const Color textSecondary = Color(0xFF9E9EB0);
  static const Color textTertiary  = Color(0xFF6A6A7E);
  static const Color textDisabled  = Color(0xFF42424F);

  // Accents
  static const Color gold           = Color(0xFFFFD60A);
  static const Color goldDim        = Color(0xFF3A2E08);
  static const Color greenOwned     = Color(0xFF30D158);
  static const Color greenOwnedDim  = Color(0xFF0E2E18);
  static const Color redDestructive = Color(0xFFFF453A);

  // Skeleton
  static const Color skeletonBase      = Color(0xFF222228);
  static const Color skeletonHighlight = Color(0xFF2E2E38);

  // Snackbar
  static const Color snackbar = Color(0xFF2C2C36);

  static Color white(double o) => Colors.white.withOpacity(o);
  static Color gold_(double o) => gold.withOpacity(o);
  static Color green_(double o) => greenOwned.withOpacity(o);
  static Color red_(double o) => redDestructive.withOpacity(o);
}