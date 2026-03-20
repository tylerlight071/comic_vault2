// lib/theme/utils/haptics.dart
//
// Centralised haptic feedback so every interaction feels consistent.
// Usage: AppHaptics.light(), AppHaptics.medium(), AppHaptics.heavy(), AppHaptics.select()

import 'package:flutter/services.dart';

class AppHaptics {
  AppHaptics._();

  /// Subtle — card taps, chip selections, filter changes
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Moderate — adding to library, toggling read, starring
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Strong — destructive actions (delete, clear all)
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// Soft click — navigation, bottom sheet open, tab switches
  static Future<void> select() => HapticFeedback.selectionClick();

  /// Success pattern — two light taps (comic added, refresh complete)
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Warning pattern — medium then light (confirm dialogs)
  static Future<void> warning() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }
}