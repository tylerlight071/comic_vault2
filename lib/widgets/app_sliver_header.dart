// lib/widgets/app_sliver_header.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// A consistent sliver app bar used across most screens.
///
/// Matches the layout from Series Tracker: a small uppercase subtitle above
/// a bold title, plus a single optional leading action.
class AppSliverHeader extends StatelessWidget {
  /// The primary title (large text).
  final String title;

  /// Optional secondary title shown above the primary title.
  final String? subtitle;

  /// Optional leading widget. If [onBack] is provided, it will be used to
  /// build a back button instead.
  final Widget? leading;

  /// If provided, a default back button is shown.
  final VoidCallback? onBack;

  /// Additional actions to show on the right side.
  final List<Widget>? actions;

  const AppSliverHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onBack,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.bgElevated,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColors.border.withOpacity(0.5),
        ),
      ),
      leading: leading ??
          (onBack != null
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: Pressable(
                    onTap: onBack!,
                    haptic: HapticStyle.select,
                    scaleDown: 0.88,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: AppColors.textSecondary, size: 16),
                    ),
                  ),
                )
              : null),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitle != null) ...[
            Text(
              subtitle!.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: actions,
    );
  }
}
