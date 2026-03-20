// lib/theme/home_typography.dart
//
// Shared typography helpers used across the home-screen part files.
// Import this file wherever tDisplay / tUi are needed.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';


TextStyle tDisplay(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w700,
  double? height,
  double letterSpacing = -0.5,
}) =>
    GoogleFonts.playfairDisplay(
      color: color ?? AppColors.textPrimary,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );

TextStyle tUi(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w500,
  double? height,
  double letterSpacing = 0,
}) =>
    GoogleFonts.dmSans(
      color: color ?? AppColors.textPrimary,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );