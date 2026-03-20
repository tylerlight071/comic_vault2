// lib/widgets/skeleton_box.dart
//
// Drop-in shimmer skeleton. Use as CachedNetworkImage placeholder,
// list placeholders, or anywhere content is loading.
//
// Usage:
//   CachedNetworkImage(
//     placeholder: (_, __) => const SkeletonBox(),
//     ...
//   )

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';


class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(0)),
  });

  /// Convenience: rounded pill (e.g. text line placeholders)
  const SkeletonBox.pill({
    super.key,
    this.width,
    this.height = 12,
  }) : borderRadius = const BorderRadius.all(Radius.circular(6));

  /// Convenience: card cover placeholder
  const SkeletonBox.cover({super.key, this.width, this.height})
      : borderRadius = const BorderRadius.all(Radius.circular(0));

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: Color.lerp(
            AppColors.skeletonBase,
            AppColors.skeletonHighlight,
            _anim.value,
          ),
        ),
      ),
    );
  }
}

/// A full comic card skeleton — matches the exact proportions of ComicCard.
class SkeletonComicCard extends StatelessWidget {
  const SkeletonComicCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const SkeletonBox.cover(),
          // Bottom gradient overlay mock
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.surface1,
                    AppColors.surface1.withOpacity(0),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SkeletonBox.pill(width: 30),
                  SizedBox(height: 5),
                  SkeletonBox.pill(width: double.infinity),
                  SizedBox(height: 4),
                  SkeletonBox.pill(width: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A shelf card skeleton — matches _Shelf item proportions.
class SkeletonShelfCard extends StatelessWidget {
  const SkeletonShelfCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: const SkeletonBox.cover(),
            ),
          ),
          const SizedBox(height: 7),
          const SkeletonBox.pill(width: 30, height: 10),
          const SizedBox(height: 4),
          const SkeletonBox.pill(width: double.infinity, height: 10),
          const SizedBox(height: 3),
          const SkeletonBox.pill(width: 60, height: 10),
        ],
      ),
    );
  }
}

/// A list row skeleton — matches search result / wishlist card.
class SkeletonListRow extends StatelessWidget {
  const SkeletonListRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          // Cover
          ClipRRect(
            borderRadius:
                BorderRadius.horizontal(left: Radius.circular(14)),
            child: SizedBox(width: 68, child: SkeletonBox.cover()),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonBox.pill(width: 80, height: 10),
                SizedBox(height: 7),
                SkeletonBox.pill(width: double.infinity, height: 13),
                SizedBox(height: 4),
                SkeletonBox.pill(width: 120, height: 12),
                SizedBox(height: 8),
                Row(children: [
                  SkeletonBox.pill(width: 32, height: 18),
                  SizedBox(width: 4),
                  SkeletonBox.pill(width: 32, height: 18),
                ]),
              ],
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
    );
  }
}