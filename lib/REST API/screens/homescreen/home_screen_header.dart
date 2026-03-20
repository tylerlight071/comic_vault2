// lib/REST API/screens/home_screen_header.dart

// ignore_for_file: deprecated_member_use

part of 'home_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// HEADER — search bar with inline scan button
// ══════════════════════════════════════════════════════════════════════════════

class _PremiumHeader extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onScan;
  final VoidCallback onMenu;

  const _PremiumHeader({
    required this.onSearch,
    required this.onScan,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(
          bottom:
              BorderSide(color: AppColors.border.withOpacity(0.5), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Pressable(
                onTap: onMenu,
                haptic: HapticStyle.select,
                scaleDown: 0.88,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.menu_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    // Search tap target
                    Expanded(
                      child: Pressable(
                        onTap: onSearch,
                        haptic: HapticStyle.select,
                        scaleDown: 0.985,
                        child: Row(children: [
                          const SizedBox(width: 14),
                          Icon(Icons.search_rounded,
                              color: AppColors.textTertiary.withOpacity(0.6),
                              size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'Search titles, series, creators…',
                            style: tUi(14,
                                color: AppColors.textTertiary.withOpacity(0.7),
                                weight: FontWeight.w400),
                          ),
                        ]),
                      ),
                    ),
                    // Divider
                    Container(width: 1, height: 24, color: AppColors.border),
                    // Scan button
                    Pressable(
                      onTap: onScan,
                      haptic: HapticStyle.medium,
                      scaleDown: 0.88,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.qr_code_scanner_rounded,
                            color: AppColors.textSecondary, size: 19),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mosaic floating header ────────────────────────────────────────────────────

class _MosaicFloatingHeader extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onMenu;

  const _MosaicFloatingHeader({
    required this.onSearch,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Expanded(
            child: Pressable(
              onTap: onSearch,
              haptic: HapticStyle.select,
              scaleDown: 0.97,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search_rounded,
                          color: Colors.white.withOpacity(0.4), size: 17),
                      const SizedBox(width: 8),
                      Text('Search…',
                          style: tUi(13,
                              color: Colors.white.withOpacity(0.35),
                              weight: FontWeight.w400)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: onMenu,
            haptic: HapticStyle.select,
            scaleDown: 0.88,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(Icons.menu_rounded,
                      color: Colors.white.withOpacity(0.6), size: 20),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}