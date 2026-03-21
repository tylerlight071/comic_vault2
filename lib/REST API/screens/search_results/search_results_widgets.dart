// lib/REST API/screens/search_results_widgets.dart
part of 'search_results_screen.dart';

// ── Suggestion model ──────────────────────────────────────────────────────────

class _SeriesSuggestion {
  final String seriesName;
  final String? publisher;
  final int? startYear;
  final String searchQuery;

  const _SeriesSuggestion({
    required this.seriesName,
    this.publisher,
    this.startYear,
    required this.searchQuery,
  });

  String get displayLabel {
    final parts = <String>[seriesName];
    if (publisher != null && publisher!.isNotEmpty) parts.add(publisher!);
    if (startYear != null) parts.add('$startYear');
    return parts.join(' · ');
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatefulWidget {
  final Comic comic;
  final bool isOwned;
  final bool isWishlisted;
  final VoidCallback onTap;

  const _ResultCard({
    required this.comic,
    required this.isOwned,
    required this.isWishlisted,
    required this.onTap,
  });

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  Color _palette = Colors.black;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(_ResultCard old) {
    super.didUpdateWidget(old);
    if (old.comic.coverImageUrl != widget.comic.coverImageUrl) _loadPalette();
  }

  Future<void> _loadPalette() async {
    final c = await CoverPaletteService.instance
        .getColor(widget.comic.coverImageUrl);
    if (mounted) setState(() => _palette = c);
  }

  @override
  Widget build(BuildContext context) {
    final comic       = widget.comic;
    final borderColor = widget.isOwned
        ? AppColors.green_(0.25)
        : widget.isWishlisted
            ? AppColors.gold_(0.18)
            : AppColors.border;

    return Pressable(
      onTap: widget.onTap,
      haptic: HapticStyle.light,
      scaleDown: 0.97,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          // ── Cover with palette gradient ──────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(13)),
            child: SizedBox(
              width: 76,
              height: 114,
              child: Stack(fit: StackFit.expand, children: [
                comic.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: comic.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SkeletonBox.cover(),
                        errorWidget: (_, __, ___) =>
                            Container(color: AppColors.surface2),
                      )
                    : Container(
                        color: AppColors.surface2,
                        child: const Center(
                          child: Icon(Icons.menu_book_rounded,
                              color: AppColors.textDisabled, size: 28),
                        ),
                      ),
                // Palette-tinted right-edge fade blends into the card body
                Positioned(
                  top: 0, right: 0, bottom: 0,
                  width: 40,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          _palette.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Text content ─────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comic.seriesName,
                    style: tUi(11,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comic.title.isNotEmpty
                        ? comic.title
                        : 'Issue #${comic.issueNumber ?? "?"}',
                    style: tUi(14,
                        color: AppColors.textPrimary,
                        weight: FontWeight.w700,
                        height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    if (comic.issueNumber != null)
                      _chip('#${comic.issueNumber}'),
                    if (comic.publicationYear != null)
                      _chip('${comic.publicationYear}'),
                    if (comic.publisher != null)
                      _chip(comic.publisher!, dim: true),
                  ]),
                ],
              ),
            ),
          ),

          // ── Status icon ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(
              widget.isOwned
                  ? Icons.check_circle_rounded
                  : widget.isWishlisted
                      ? Icons.bookmark_rounded
                      : Icons.chevron_right_rounded,
              color: widget.isOwned
                  ? AppColors.greenOwned
                  : widget.isWishlisted
                      ? AppColors.gold
                      : AppColors.textDisabled,
              size: widget.isOwned || widget.isWishlisted ? 20 : 16,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, {bool dim = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: tUi(10,
              color:
                  dim ? AppColors.textTertiary : AppColors.textSecondary,
              weight: FontWeight.w600),
        ),
      );
}

// ── Skeleton result card ──────────────────────────────────────────────────────

class _SkeletonResultCard extends StatelessWidget {
  const _SkeletonResultCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 114,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 76,
          decoration: BoxDecoration(
            color: AppColors.skeletonBase,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(13)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(
                    height: 14,
                    width: 160,
                    decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(
                    height: 14,
                    width: 100,
                    decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(4))),
                const Spacer(),
                Row(children: [
                  Container(
                      height: 22,
                      width: 36,
                      decoration: BoxDecoration(
                          color: AppColors.skeletonBase,
                          borderRadius: BorderRadius.circular(5))),
                  const SizedBox(width: 6),
                  Container(
                      height: 22,
                      width: 36,
                      decoration: BoxDecoration(
                          color: AppColors.skeletonBase,
                          borderRadius: BorderRadius.circular(5))),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
