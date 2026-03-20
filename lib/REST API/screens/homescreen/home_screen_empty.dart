// lib/REST API/screens/homescreen/home_screen_empty.dart

// ignore_for_file: deprecated_member_use

part of 'home_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final VoidCallback onScanTap;
  const _EmptyState({required this.onScanTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
            // ── Logo mark ─────────────────────────────────────────────────
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.menu_book_rounded,
                  color: AppColors.bg, size: 24),
            )
                .animate()
                .fadeIn(duration: 450.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 24),

            // ── Heading ───────────────────────────────────────────────────
            Text(
              'Your vault\nawaits.',
              style: tDisplay(34,
                  weight: FontWeight.w700,
                  height: 1.12,
                  letterSpacing: -0.8),
            )
                .animate(delay: 80.ms)
                .fadeIn(duration: 450.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 12),

            Text(
              'Scan a barcode to add your first comic\nand start building your collection.',
              style: tUi(15,
                  color: AppColors.textTertiary,
                  weight: FontWeight.w400,
                  height: 1.55),
            )
                .animate(delay: 140.ms)
                .fadeIn(duration: 450.ms),

            const SizedBox(height: 36),

            // ── Feature callouts ──────────────────────────────────────────
            ...[
              _Feature(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan any barcode',
                description:
                    'Covers, credits and synopsis pulled automatically.',
              ),
              _Feature(
                icon: Icons.auto_stories_rounded,
                label: 'Track your runs',
                description:
                    'See which issues you own, want, and still need.',
              ),
              _Feature(
                icon: Icons.star_rounded,
                label: 'Rate and organise',
                description: 'Star ratings, read status and a wishlist.',
                accentColor: AppColors.gold,
              ),
            ].asMap().entries.map((e) => e.value
                .animate(
                    delay: Duration(milliseconds: 200 + e.key * 65))
                .fadeIn(duration: 380.ms)
                .slideX(
                    begin: 0.04,
                    end: 0,
                    curve: Curves.easeOutCubic)),

            const SizedBox(height: 36),

            // ── CTA ───────────────────────────────────────────────────────
            Pressable(
              onTap: onScanTap,
              haptic: HapticStyle.medium,
              scaleDown: 0.96,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        color: AppColors.bg, size: 19),
                    const SizedBox(width: 10),
                    Text('Scan a Comic',
                        style: tUi(15,
                            color: AppColors.bg,
                            weight: FontWeight.w700)),
                  ],
                ),
              ),
            )
                .animate(delay: 420.ms)
                .fadeIn(duration: 400.ms)
                .slideY(
                    begin: 0.06,
                    end: 0,
                    curve: Curves.easeOutCubic),

            const SizedBox(height: 12),

            Center(
              child: Text(
                'No account. No cloud. No ads.',
                style: tUi(12,
                    color: AppColors.textDisabled,
                    weight: FontWeight.w400),
              ),
            )
                .animate(delay: 480.ms)
                .fadeIn(duration: 380.ms),
          ],
          ),
        ),
      ),
    );
  }
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color? accentColor;

  const _Feature({
    required this.icon,
    required this.label,
    required this.description,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: tUi(13,
                        color: AppColors.textPrimary,
                        weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description,
                    style: tUi(12,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w400,
                        height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}