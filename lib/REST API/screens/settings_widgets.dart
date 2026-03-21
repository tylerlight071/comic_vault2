// lib/REST API/screens/settings_widgets.dart
part of 'settings_screen.dart';

// ── Action tile ────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String description;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? borderColor;
  final bool isFirst;
  final bool isLast;

  const _ActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.onTap,
    this.labelColor,
    this.borderColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    BorderRadius radius = BorderRadius.zero;
    if (isFirst && isLast) radius = BorderRadius.circular(14);
    else if (isFirst) radius = const BorderRadius.vertical(top: Radius.circular(14));
    else if (isLast)  radius = const BorderRadius.vertical(bottom: Radius.circular(14));

    return Pressable(
      onTap: onTap,
      haptic: HapticStyle.none,
      scaleDown: 0.98,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: radius,
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: borderColor?.withOpacity(0.4) ?? AppColors.border),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: tUi(14,
                        color: labelColor ?? AppColors.textPrimary,
                        weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description,
                    style: tUi(12,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w400,
                        height: 1.4)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textDisabled, size: 18),
        ]),
      ),
    );
  }
}

// ── Info row model ─────────────────────────────────────────────────────────────

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
}
