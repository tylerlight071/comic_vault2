// lib/REST API/screens/home_screen_skeletons.dart

part of 'home_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SKELETON STATES
// ══════════════════════════════════════════════════════════════════════════════

class _SkeletonHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgElevated,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox.pill(width: 190, height: 34),
                      SizedBox(height: 6),
                      SkeletonBox.pill(width: 90, height: 12),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const SkeletonBox.pill(width: 44, height: 44),
              ]),
              const SizedBox(height: 20),
              SkeletonBox(
                  width: double.infinity,
                  height: 48,
                  borderRadius: BorderRadius.circular(13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonShelf extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: _Shelf(
          title: '', comics: const [], onTap: (_) {}, showSkeleton: true),
    );
  }
}