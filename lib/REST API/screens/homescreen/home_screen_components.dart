// lib/REST API/screens/homescreen/home_screen_components.dart

// ignore_for_file: deprecated_member_use

part of 'home_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SHELF TYPE — drives visual identity per section
// ══════════════════════════════════════════════════════════════════════════════

enum _ShelfType { recentlyAdded, continueReading, topRated }

extension _ShelfTypeStyle on _ShelfType {
  Color get accentColor {
    switch (this) {
      case _ShelfType.recentlyAdded:   return AppColors.accent;
      case _ShelfType.continueReading: return AppColors.textPrimary;
      case _ShelfType.topRated:        return AppColors.gold;
    }
  }

  IconData get icon {
    switch (this) {
      case _ShelfType.recentlyAdded:   return Icons.schedule_rounded;
      case _ShelfType.continueReading: return Icons.auto_stories_rounded;
      case _ShelfType.topRated:        return Icons.star_rounded;
    }
  }

  double get cardWidth {
    switch (this) {
      case _ShelfType.recentlyAdded:   return 124;
      case _ShelfType.continueReading: return 158;
      case _ShelfType.topRated:        return 124;
    }
  }

  double get shelfHeight {
    switch (this) {
      case _ShelfType.recentlyAdded:   return 210;
      case _ShelfType.continueReading: return 232;
      case _ShelfType.topRated:        return 210;
    }
  }

  // Fixed pixel height for the cover image portion of a shelf card.
  //
  // By decoupling the cover height from the text below it, every card in a
  // shelf has an identical image size regardless of whether the series name
  // wraps to one line or two. The text sits in the remaining space below.
  //
  // Breakdown for recentlyAdded / topRated (shelfHeight = 210):
  //   coverHeight (140) + gap (8) + issueNumber (~12) + gap (1)
  //   + seriesName (≤2 lines, ~28) + gap (3) + date (~12) = 204  ✓
  //
  // Breakdown for continueReading (shelfHeight = 232):
  //   Text is overlaid inside the image, so coverHeight == shelfHeight.
  double get coverHeight {
    switch (this) {
      case _ShelfType.recentlyAdded:   return 140;
      case _ShelfType.continueReading: return 232; // full-bleed
      case _ShelfType.topRated:        return 140;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════════

String _relativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7)  return '${diff.inDays} days ago';
  if (diff.inDays < 14) return 'Last week';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
  if (diff.inDays < 60) return 'Last month';
  return '${(diff.inDays / 30).floor()} months ago';
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ══════════════════════════════════════════════════════════════════════════════

class _CoverImage extends StatelessWidget {
  final String? url;
  const _CoverImage({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        color: AppColors.surface2,
        child: Center(
            child: Icon(Icons.menu_book_rounded,
                color: AppColors.textDisabled.withOpacity(0.4), size: 26)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => const SkeletonBox.cover(),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.surface2,
        child: Center(
            child: Icon(Icons.broken_image_rounded,
                color: AppColors.textDisabled.withOpacity(0.4), size: 20)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// READING PROGRESS RIBBON
// ══════════════════════════════════════════════════════════════════════════════

class _ReadingProgressRibbon extends StatefulWidget {
  final List<Comic> all;
  final Comic? featured;

  const _ReadingProgressRibbon({required this.all, this.featured});

  @override
  State<_ReadingProgressRibbon> createState() =>
      _ReadingProgressRibbonState();
}

class _ReadingProgressRibbonState extends State<_ReadingProgressRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;
  Color _barColor = AppColors.textDisabled;

  @override
  void initState() {
    super.initState();
    final read  = widget.all.where((c) => c.isRead).length;
    final total = widget.all.length;
    final pct   = total == 0 ? 0.0 : read / total;

    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950));
    _progress = Tween<double>(begin: 0, end: pct)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance
        .addPostFrameCallback((_) { if (mounted) _ctrl.forward(); });

    _loadPalette();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadPalette() async {
    if (widget.featured == null) return;
    final color = await CoverPaletteService.instance
        .getColor(widget.featured!.coverImageUrl);
    if (mounted) setState(() => _barColor = color);
  }

  @override
  Widget build(BuildContext context) {
    final read   = widget.all.where((c) => c.isRead).length;
    final total  = widget.all.length;
    final series = widget.all.map((c) => c.seriesName).toSet().length;
    final pct    = total == 0 ? 0 : ((read / total) * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$read',
                  style: tDisplay(26,
                      weight: FontWeight.w700, letterSpacing: -0.8)),
              const SizedBox(width: 5),
              Text('read',
                  style: tUi(13,
                      color: AppColors.textTertiary, weight: FontWeight.w400)),
              const Spacer(),
              Text('$total comics',
                  style: tUi(12,
                      color: AppColors.textTertiary, weight: FontWeight.w400)),
              Text('  ·  ', style: tUi(12, color: AppColors.textDisabled)),
              Text('$series series',
                  style: tUi(12,
                      color: AppColors.textTertiary, weight: FontWeight.w400)),
            ],
          ),
          const SizedBox(height: 11),
          AnimatedBuilder(
            animation: _progress,
            builder: (_, __) => LayoutBuilder(
              builder: (_, constraints) => Stack(children: [
                Container(
                  height: 5,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: AppColors.surface3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  height: 5,
                  width: constraints.maxWidth * _progress.value,
                  decoration: BoxDecoration(
                    color: _barColor,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: _barColor.withOpacity(0.55),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text('$pct% complete',
              style: tUi(10,
                  color: AppColors.textDisabled,
                  weight: FontWeight.w500,
                  letterSpacing: 0.3)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 80.ms);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHELF
// ══════════════════════════════════════════════════════════════════════════════

class _Shelf extends StatelessWidget {
  final String title;
  final List<Comic> comics;
  final void Function(Comic) onTap;
  final VoidCallback? onSeeAll;
  final bool showSkeleton;
  final _ShelfType shelfType;

  const _Shelf({
    required this.title,
    required this.comics,
    required this.onTap,
    this.onSeeAll,
    this.shelfType = _ShelfType.recentlyAdded,
    this.showSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
    if (comics.isEmpty && !showSkeleton) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: shelfType.accentColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 10),
              Icon(shelfType.icon, color: shelfType.accentColor, size: 13),
              const SizedBox(width: 7),
              Text(title,
                  style: tDisplay(18,
                      weight: FontWeight.w700, letterSpacing: -0.4)),
              const Spacer(),
              if (onSeeAll != null)
                Pressable(
                  onTap: onSeeAll!,
                  haptic: HapticStyle.light,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('See all',
                        style: tUi(12,
                            color: AppColors.textTertiary,
                            weight: FontWeight.w600)),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textDisabled, size: 14),
                  ]),
                )
              else if (comics.length > 6)
                Text('${comics.length}',
                    style: tUi(12,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w500)),
            ],
          ),
        ),

      SizedBox(
        height: shelfType.shelfHeight,
        child: Stack(
          children: [
            showSkeleton
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    itemBuilder: (_, __) => Container(
                      width: 124,
                      margin: const EdgeInsets.only(right: 12),
                      child: const SkeletonShelfCard(),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    itemCount: comics.length,
                    itemBuilder: (_, i) {
                      final comic = comics[i];
                      if (shelfType == _ShelfType.continueReading) {
                        return _ContinueReadingCard(
                          comic: comic,
                          index: i,
                          onTap: () {
                            AppHaptics.light();
                            onTap(comic);
                          },
                        );
                      }
                      return _PalettedShelfCard(
                        comic: comic,
                        index: i,
                        shelfType: shelfType,
                        onTap: () {
                          AppHaptics.light();
                          onTap(comic);
                        },
                      );
                    },
                  ),

            // Right-edge fade — communicates more content without a hard cut.
            // IgnorePointer ensures taps on the last card pass through cleanly.
            Positioned(
              top: 0, right: 0, bottom: 0,
              width: 52,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [AppColors.bg, AppColors.bg.withOpacity(0)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PALETTED SHELF CARD  (Recently Added + Top Rated)
// ══════════════════════════════════════════════════════════════════════════════
//
// The cover uses a FIXED height (from shelfType.coverHeight) rather than
// Expanded. This means every card in the shelf has an identical image size
// regardless of whether the series name wraps to one line or two — the text
// sits in the remaining space below the image and never affects it.

class _PalettedShelfCard extends StatefulWidget {
  final Comic comic;
  final int index;
  final _ShelfType shelfType;
  final VoidCallback onTap;

  const _PalettedShelfCard({
    required this.comic,
    required this.index,
    required this.shelfType,
    required this.onTap,
  });

  @override
  State<_PalettedShelfCard> createState() => _PalettedShelfCardState();
}

class _PalettedShelfCardState extends State<_PalettedShelfCard> {
  Color _paletteColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(_PalettedShelfCard old) {
    super.didUpdateWidget(old);
    if (old.comic.coverImageUrl != widget.comic.coverImageUrl) _loadPalette();
  }

  Future<void> _loadPalette() async {
    final color = await CoverPaletteService.instance
        .getColor(widget.comic.coverImageUrl);
    if (mounted) setState(() => _paletteColor = color);
  }

  @override
  Widget build(BuildContext context) {
    final comic      = widget.comic;
    final isTopRated = widget.shelfType == _ShelfType.topRated;
    final isRecent   = widget.shelfType == _ShelfType.recentlyAdded;
    final coverH     = widget.shelfType.coverHeight;

    return Pressable(
      onTap: widget.onTap,
      haptic: HapticStyle.none,
      scaleDown: 0.94,
      child: SizedBox(
        width: widget.shelfType.cardWidth,
        child: Container(
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // don't stretch to fill shelf height
            children: [
              // ── Cover — fixed height, always the same ──────────────────
              SizedBox(
                height: coverH,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(fit: StackFit.expand, children: [
                    _CoverImage(url: comic.coverImageUrl),

                    // Palette-tinted bottom gradient
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              _paletteColor.withOpacity(0.95),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Read check badge
                    if (comic.isRead)
                      Positioned(
                        top: 7, right: 7,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: AppColors.greenOwned, size: 12),
                        ),
                      ),

                    // Gold star badge — Top Rated only
                    if (isTopRated && comic.starRating > 0)
                      Positioned(
                        top: 7, left: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.gold_(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.star_rounded,
                                color: AppColors.gold, size: 9),
                            const SizedBox(width: 3),
                            Text('${comic.starRating}',
                                style: tUi(9,
                                    color: Colors.white,
                                    weight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ),

              // ── Text below cover ─────────────────────────────────────────
              // Lives outside the image SizedBox so it never compresses it.
              const SizedBox(height: 8),
              if (comic.issueNumber != null)
                Text('#${comic.issueNumber}',
                    style: tUi(9,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w700,
                        letterSpacing: 0.5)),
              const SizedBox(height: 1),
              Text(
                comic.seriesName,
                style: tUi(12,
                    color: AppColors.textSecondary,
                    weight: FontWeight.w600,
                    height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Relative date — Recently Added only
              if (isRecent) ...[
                const SizedBox(height: 3),
                Text(
                  _relativeDate(comic.addedDate),
                  style: tUi(10,
                      color: AppColors.textDisabled, weight: FontWeight.w400),
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.index * 50))
        .fadeIn(duration: 320.ms)
        .slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CONTINUE READING CARD
// ══════════════════════════════════════════════════════════════════════════════
//
// Full-bleed image card — text is overlaid inside the cover so there is no
// separate text section below, and no sizing issue to worry about.

class _ContinueReadingCard extends StatefulWidget {
  final Comic comic;
  final int index;
  final VoidCallback onTap;

  const _ContinueReadingCard({
    required this.comic,
    required this.index,
    required this.onTap,
  });

  @override
  State<_ContinueReadingCard> createState() => _ContinueReadingCardState();
}

class _ContinueReadingCardState extends State<_ContinueReadingCard> {
  Color _paletteColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(_ContinueReadingCard old) {
    super.didUpdateWidget(old);
    if (old.comic.coverImageUrl != widget.comic.coverImageUrl) _loadPalette();
  }

  Future<void> _loadPalette() async {
    final color = await CoverPaletteService.instance
        .getColor(widget.comic.coverImageUrl);
    if (mounted) setState(() => _paletteColor = color);
  }

  @override
  Widget build(BuildContext context) {
    final comic   = widget.comic;
    final isFirst = widget.index == 0;

    return Pressable(
      onTap: widget.onTap,
      haptic: HapticStyle.none,
      scaleDown: 0.94,
      child: Container(
        width: 158,
        margin: const EdgeInsets.only(right: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(fit: StackFit.expand, children: [
            _CoverImage(url: comic.coverImageUrl),
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    _paletteColor.withOpacity(0.97),
                    Colors.black.withOpacity(0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.48, 0.78],
                ),
              ),
            ),
            if (isFirst)
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('NEXT UP',
                      style: tUi(8,
                          color: AppColors.bg,
                          weight: FontWeight.w800,
                          letterSpacing: 1.0)),
                ),
              ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 0, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (comic.issueNumber != null)
                      Text('#${comic.issueNumber}',
                          style: tUi(9,
                              color: Colors.white.withOpacity(0.5),
                              weight: FontWeight.w700,
                              letterSpacing: 0.4)),
                    const SizedBox(height: 2),
                    Text(
                      comic.seriesName,
                      style: tUi(12,
                          color: Colors.white,
                          weight: FontWeight.w700,
                          height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.index * 50))
        .fadeIn(duration: 320.ms)
        .slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }
}