import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

class StarRatingWidget extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onRated;
  final double size;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.onRated,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        return Pressable(
          onTap: onRated == null
              ? null
              : () => onRated!(star == rating ? 0 : star),
          haptic: HapticStyle.light,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.07),
            child: Icon(
              star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
              color: star <= rating
                  ? AppColors.gold
                  : Colors.white24,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}
