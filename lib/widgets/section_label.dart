import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/typography.dart';

/// Small all-caps section header used throughout the app.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(text,
            style: tUi(10,
                color: AppColors.textTertiary,
                weight: FontWeight.w700,
                letterSpacing: 1.6)),
      );
}
