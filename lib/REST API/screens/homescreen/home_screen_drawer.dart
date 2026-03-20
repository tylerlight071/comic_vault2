// lib/REST API/screens/homescreen/home_screen_drawer.dart

// ignore_for_file: unused_element_parameter, deprecated_member_use

part of 'home_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SIDEBAR DRAWER
// ══════════════════════════════════════════════════════════════════════════════

/// Internal model for a ranked series entry.
class _SeriesEntry {
  final String name;
  final String? volumeId;
  final int issueCount;
  final double avgRating; // 0.0 if no issues are rated

  const _SeriesEntry({
    required this.name,
    required this.volumeId,
    required this.issueCount,
    required this.avgRating,
  });

  /// Weighted score: avgRating × √issueCount.
  ///
  /// Rewards series you both rate highly *and* collect deeply.
  /// Unrated series produce a score of 0 and fall back to issue count
  /// as a tiebreaker in the sort below.
  double get score => avgRating * sqrt(issueCount.toDouble());
}

class _AppDrawer extends StatelessWidget {
  final List<Comic> all;
  final int wishlistCount;
  final VoidCallback onSearch;
  final VoidCallback onSeriesTracker;
  final VoidCallback onWishlist;
  final VoidCallback onLibrary;
  final VoidCallback onStats;
  final VoidCallback onSettings;
  final VoidCallback onScan;
  final void Function(String seriesName, String volumeId) onSeriesRunTap;

  const _AppDrawer({
    required this.all,
    required this.wishlistCount,
    required this.onSearch,
    required this.onSeriesTracker,
    required this.onWishlist,
    required this.onLibrary,
    required this.onStats,
    required this.onSettings,
    required this.onScan,
    required this.onSeriesRunTap,
  });

  List<_SeriesEntry> get _topSeries {
    final map = <String, List<Comic>>{};
    for (final c in all) {
      map.putIfAbsent(c.seriesName, () => []).add(c);
    }

    final entries = map.entries.map((e) {
      final comics = e.value;
      final rated  = comics.where((c) => c.starRating > 0).toList();
      final avgRating = rated.isEmpty
          ? 0.0
          : rated.map((c) => c.starRating).reduce((a, b) => a + b) /
              rated.length;
      final volumeId = comics
          .where((c) => c.volumeId != null && c.volumeId!.isNotEmpty)
          .map((c) => c.volumeId)
          .firstOrNull;

      return _SeriesEntry(
        name: e.key,
        volumeId: volumeId,
        issueCount: comics.length,
        avgRating: avgRating,
      );
    }).toList();

    entries.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      return b.issueCount.compareTo(a.issueCount);
    });

    return entries.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = all.where((c) => !c.isRead).length;
    final topSeries   = _topSeries;

    return Drawer(
      width: 300,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          border: Border(
            right: BorderSide(color: AppColors.border.withOpacity(0.5)),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Branding ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.menu_book_rounded,
                        color: AppColors.bg, size: 17),
                  ),
                  const SizedBox(width: 11),
                  Text('ComicVault',
                      style: tDisplay(19,
                          weight: FontWeight.w700, letterSpacing: -0.4)),
                ]),
              ),

              const SizedBox(height: 22),

              // ── Scan shortcut ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Pressable(
                  onTap: onScan,
                  haptic: HapticStyle.medium,
                  scaleDown: 0.97,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded,
                            color: AppColors.bg, size: 18),
                        const SizedBox(width: 9),
                        Text('Scan a Comic',
                            style: tUi(14,
                                color: AppColors.bg,
                                weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Divider(
                    color: AppColors.border.withOpacity(0.4), height: 1),
              ),

              const SizedBox(height: 10),

              // ── Navigation ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                child: Text('NAVIGATE',
                    style: tUi(10,
                        color: AppColors.textDisabled,
                        weight: FontWeight.w700,
                        letterSpacing: 1.8)),
              ),

              _DrawerItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isActive: true,
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.library_books_rounded,
                label: 'Library',
                badge: unreadCount > 0 ? '$unreadCount unread' : null,
                onTap: onLibrary,
              ),
              _DrawerItem(
                icon: Icons.auto_stories_rounded,
                label: 'Series Tracker',
                onTap: onSeriesTracker,
              ),
              _DrawerItem(
                icon: Icons.bookmark_rounded,
                label: 'Wishlist',
                badge: wishlistCount > 0 ? '$wishlistCount' : null,
                onTap: onWishlist,
              ),
              _DrawerItem(
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                onTap: onStats,
              ),

              // ── Top series ──────────────────────────────────────────────
              if (topSeries.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Divider(
                      color: AppColors.border.withOpacity(0.4), height: 1),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                  child: Text('TOP SERIES',
                      style: tUi(10,
                          color: AppColors.textDisabled,
                          weight: FontWeight.w700,
                          letterSpacing: 1.8)),
                ),
                ...topSeries.map((entry) => _TopSeriesRow(
                      entry: entry,
                      onTap: entry.volumeId != null
                          ? () => onSeriesRunTap(entry.name, entry.volumeId!)
                          : null,
                    )),
              ],

              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Divider(
                    color: AppColors.border.withOpacity(0.4), height: 1),
              ),

              const SizedBox(height: 4),

              _DrawerItem(
                icon: Icons.tune_rounded,
                label: 'Settings',
                onTap: onSettings,
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top series row ────────────────────────────────────────────────────────────

class _TopSeriesRow extends StatelessWidget {
  final _SeriesEntry entry;
  final VoidCallback? onTap;

  const _TopSeriesRow({required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;

    return Pressable(
      onTap: onTap ?? () {},
      haptic: tappable ? HapticStyle.select : HapticStyle.none,
      scaleDown: tappable ? 0.97 : 1.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: tUi(13,
                      color: tappable
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                      weight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.avgRating > 0) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.gold, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      entry.avgRating.toStringAsFixed(1),
                      style: tUi(10,
                          color: AppColors.textDisabled,
                          weight: FontWeight.w500),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${entry.issueCount} ${entry.issueCount == 1 ? 'issue' : 'issues'}',
                style: tUi(10,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w600),
              ),
            ),
            if (tappable) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textDisabled, size: 15),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? accent;
  final String? badge;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.accent,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        accent ?? (isActive ? AppColors.textPrimary : AppColors.textSecondary);
    final labelColor =
        isActive ? AppColors.textPrimary : AppColors.textSecondary;

    return Pressable(
      onTap: onTap,
      haptic: HapticStyle.select,
      scaleDown: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.border : Colors.transparent,
          ),
        ),
        child: Row(children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 14),
          Text(label,
              style: tUi(14,
                  color: labelColor,
                  weight: isActive ? FontWeight.w700 : FontWeight.w500)),
          const Spacer(),
          if (isActive)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                shape: BoxShape.circle,
              ),
            )
          else if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(badge!,
                  style: tUi(10,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }
}