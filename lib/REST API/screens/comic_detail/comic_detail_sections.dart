// lib/REST API/screens/comic_detail_sections.dart
part of 'comic_detail_screen.dart';

// ── Condition section ──────────────────────────────────────────────────────────

class _ConditionSection extends StatelessWidget {
  final String? condition;
  final void Function(String) onSelect;

  const _ConditionSection({required this.condition, required this.onSelect});

  static const _conditions = ['NM', 'VF', 'FN', 'VG', 'G', 'FR'];
  static const _conditionLabels = {
    'NM': 'Near Mint',
    'VF': 'Very Fine',
    'FN': 'Fine',
    'VG': 'Very Good',
    'G': 'Good',
    'FR': 'Fair',
  };

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONDITION',
              style: tUi(10,
                  color: AppColors.textTertiary,
                  weight: FontWeight.w700,
                  letterSpacing: 1.6)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _conditions.map((grade) {
              final selected = condition == grade;
              return Pressable(
                onTap: () => onSelect(grade),
                haptic: HapticStyle.light,
                scaleDown: 0.92,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.surface3 : AppColors.surface1,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppColors.borderFocus
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(grade,
                          style: tUi(13,
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              weight: FontWeight.w700)),
                      Text(_conditionLabels[grade]!,
                          style: tUi(10,
                              color: selected
                                  ? AppColors.textSecondary
                                  : AppColors.textTertiary,
                              weight: FontWeight.w400)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ).animate().fadeIn(delay: 280.ms);
}

// ── Notes section ──────────────────────────────────────────────────────────────

class _NotesSection extends StatelessWidget {
  final String? notes;
  final VoidCallback onTap;

  const _NotesSection({required this.notes, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('NOTES',
                style: tUi(10,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const Spacer(),
            Pressable(
              onTap: onTap,
              haptic: HapticStyle.light,
              child: Text(
                notes == null ? 'Add' : 'Edit',
                style: tUi(12,
                    color: AppColors.textTertiary, weight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Pressable(
            onTap: onTap,
            haptic: HapticStyle.light,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: notes != null
                  ? Text(notes!,
                      style: tUi(14,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w400,
                          height: 1.6))
                  : Text('Tap to add personal notes…',
                      style: tUi(14,
                          color: AppColors.textDisabled,
                          weight: FontWeight.w400)),
            ),
          ),
        ],
      ).animate().fadeIn(delay: 290.ms);
}

// ── Purchase price section ─────────────────────────────────────────────────────

class _PurchasePriceSection extends StatelessWidget {
  final double? purchasePrice;
  final VoidCallback onTap;
  final String currencySymbol;

  const _PurchasePriceSection({
    required this.purchasePrice,
    required this.onTap,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('PURCHASE PRICE',
                style: tUi(10,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const Spacer(),
            Pressable(
              onTap: onTap,
              haptic: HapticStyle.light,
              child: Text(
                purchasePrice == null ? 'Add' : 'Edit',
                style:
                    tUi(12, color: AppColors.textTertiary, weight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Pressable(
            onTap: onTap,
            haptic: HapticStyle.light,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: purchasePrice != null
                  ? Row(children: [
                      Text(currencySymbol,
                          style: tUi(15,
                              color: AppColors.greenOwned,
                              weight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Text(purchasePrice!.toStringAsFixed(2),
                          style: tUi(14,
                              color: AppColors.textSecondary,
                              weight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      Text('paid',
                          style: tUi(14,
                              color: AppColors.textSecondary,
                              weight: FontWeight.w500)),
                    ])
                  : Text('Tap to record what you paid…',
                      style: tUi(14,
                          color: AppColors.textDisabled,
                          weight: FontWeight.w400)),
            ),
          ),
        ],
      ).animate().fadeIn(delay: 285.ms);
}

// ── Tags section ───────────────────────────────────────────────────────────────

class _TagsSection extends StatelessWidget {
  final List<String> tags;
  final void Function(List<String>) onTagsChanged;

  const _TagsSection({required this.tags, required this.onTagsChanged});

  static const _suggestedTags = [
    'Key Issue', 'First Appearance', 'Signed', 'CGC Graded',
    'Variant Cover', '1st Print', 'Newsstand',
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TAGS',
              style: tUi(10,
                  color: AppColors.textTertiary,
                  weight: FontWeight.w700,
                  letterSpacing: 1.6)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Existing tags — tappable to remove
              ...tags.map((tag) => Pressable(
                onTap: () {
                  AppHaptics.light();
                  final updated = [...tags]..remove(tag);
                  onTagsChanged(updated);
                },
                haptic: HapticStyle.none,
                scaleDown: 0.92,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface3,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderFocus),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(tag,
                        style: tUi(12,
                            color: AppColors.textPrimary,
                            weight: FontWeight.w600)),
                    const SizedBox(width: 5),
                    const Icon(Icons.close_rounded,
                        color: AppColors.textTertiary, size: 12),
                  ]),
                ),
              )),
              // Suggested tags not yet added
              ..._suggestedTags
                  .where((t) => !tags.contains(t))
                  .map((tag) => Pressable(
                onTap: () {
                  AppHaptics.light();
                  onTagsChanged([...tags, tag]);
                },
                haptic: HapticStyle.none,
                scaleDown: 0.92,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded,
                        color: AppColors.textSecondary, size: 13),
                    const SizedBox(width: 4),
                    Text(tag,
                        style: tUi(12,
                            color: AppColors.textSecondary,
                            weight: FontWeight.w500)),
                  ]),
                ),
              )),
            ],
          ),
        ],
      ).animate().fadeIn(delay: 287.ms);
}

// ── Loan section ───────────────────────────────────────────────────────────────

class _LoanSection extends StatelessWidget {
  final String? loanedTo;
  final VoidCallback onLoan;
  final VoidCallback onReturn;

  const _LoanSection({
    required this.loanedTo,
    required this.onLoan,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LOAN',
              style: tUi(10,
                  color: AppColors.textTertiary,
                  weight: FontWeight.w700,
                  letterSpacing: 1.6)),
          const SizedBox(height: 12),
          if (loanedTo != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.goldDim,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold_(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.person_rounded,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Loaned out',
                          style: tUi(10,
                              color: AppColors.gold,
                              weight: FontWeight.w700,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(loanedTo!,
                          style: tUi(14,
                              color: AppColors.textPrimary,
                              weight: FontWeight.w600)),
                    ],
                  ),
                ),
                Pressable(
                  onTap: onReturn,
                  haptic: HapticStyle.medium,
                  scaleDown: 0.92,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('Returned',
                        style: tUi(12,
                            color: AppColors.textSecondary,
                            weight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Pressable(
              onTap: onLoan,
              haptic: HapticStyle.light,
              child: Text('Edit name',
                  style: tUi(12,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w500)),
            ),
          ] else
            Pressable(
              onTap: onLoan,
              haptic: HapticStyle.light,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(children: [
                  Icon(Icons.person_add_outlined,
                      color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Text('Loan out to someone…',
                      style: tUi(14,
                          color: AppColors.textDisabled,
                          weight: FontWeight.w400)),
                ]),
              ),
            ),
        ],
      ).animate().fadeIn(delay: 289.ms);
}
