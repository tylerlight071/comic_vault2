// lib/REST API/screens/homescreen/home_screen_layouts.dart

// ignore_for_file: deprecated_member_use

part of 'home_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// LAYOUT 1 — FEATURED
// ══════════════════════════════════════════════════════════════════════════════

class _FeaturedLayout extends StatelessWidget {
  final List<Comic> all;
  final List<Comic> recentlyAdded;
  final List<Comic> continueReading;
  final List<Comic> topRated;
  final Comic? featuredComic;
  final _LayoutCallbacks cb;

  const _FeaturedLayout({
    required this.all,
    required this.recentlyAdded,
    required this.continueReading,
    required this.topRated,
    required this.featuredComic,
    required this.cb,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: cb.onRefresh,
      color: AppColors.textPrimary,
      backgroundColor: AppColors.surface2,
      strokeWidth: 2,
      displacement: 60,
      child: CustomScrollView(
        physics: const BottomBouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
              child: _PremiumHeader(
                  onSearch: cb.onSearchTap,
                  onScan: cb.onScanTap,
                  onMenu: cb.onMenuTap)),
          if (all.isEmpty)
            SliverFillRemaining(child: _EmptyState(onScanTap: cb.onScanTap))
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
                child: _FeaturedHero(
                  comic: featuredComic!,
                  onTap: () {
                    AppHaptics.light();
                    cb.onComicTap(featuredComic!);
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 26),
                child: _ReadingProgressRibbon(
                    all: all, featured: featuredComic),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(children: [
                if (recentlyAdded.isNotEmpty) ...[
                  _Shelf(
                    title: 'Recently Added',
                    comics: recentlyAdded,
                    onTap: cb.onComicTap,
                    shelfType: _ShelfType.recentlyAdded,
                  ),
                  const SizedBox(height: 36),
                ],
                if (continueReading.isNotEmpty) ...[
                  _Shelf(
                    title: 'Continue Reading',
                    comics: continueReading,
                    onTap: cb.onComicTap,
                    shelfType: _ShelfType.continueReading,
                  ),
                  const SizedBox(height: 36),
                ],
                if (topRated.isNotEmpty) ...[
                  _Shelf(
                    title: 'Top Rated',
                    comics: topRated,
                    onTap: cb.onComicTap,
                    shelfType: _ShelfType.topRated,
                  ),
                  const SizedBox(height: 36),
                ],
                const SizedBox(height: 90),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Cinematic featured hero ───────────────────────────────────────────────────

class _FeaturedHero extends StatefulWidget {
  final Comic comic;
  final VoidCallback onTap;
  const _FeaturedHero({required this.comic, required this.onTap});

  @override
  State<_FeaturedHero> createState() => _FeaturedHeroState();
}

class _FeaturedHeroState extends State<_FeaturedHero> {
  Color _paletteColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(_FeaturedHero old) {
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
    final comic = widget.comic;
    return Pressable(
      onTap: widget.onTap,
      haptic: HapticStyle.none,
      scaleDown: 0.983,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 340,
          child: Stack(fit: StackFit.expand, children: [
            if (comic.coverImageUrl != null)
              CachedNetworkImage(
                imageUrl: comic.coverImageUrl!,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.5),
                colorBlendMode: BlendMode.darken,
                placeholder: (_, __) => Container(color: AppColors.surface2),
              )
            else
              Container(color: AppColors.surface2),

            AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _paletteColor.withOpacity(0.55),
                    _paletteColor.withOpacity(0.20),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.65],
                ),
              ),
            ),

            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x55000000),
                    Color(0xDD000000),
                  ],
                  stops: [0.25, 0.55, 1.0],
                ),
              ),
            ),

            Positioned(
              top: 22,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  width: 122,
                  height: 184,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: _paletteColor.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: _CoverImage(url: comic.coverImageUrl),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 18,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Text('SPOTLIGHT',
                          style: tUi(9,
                              color: Colors.white.withOpacity(0.5),
                              weight: FontWeight.w800,
                              letterSpacing: 1.8)),
                    ),
                    if (comic.isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('READ',
                            style: tUi(9,
                                color: Colors.white.withOpacity(0.35),
                                weight: FontWeight.w700,
                                letterSpacing: 1.2)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  Text(comic.seriesName,
                      style: tUi(12,
                          color: Colors.white.withOpacity(0.5),
                          weight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(
                    comic.title.isNotEmpty
                        ? comic.title
                        : 'Issue #${comic.issueNumber ?? "?"}',
                    style: tDisplay(21,
                        color: Colors.white,
                        weight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (comic.starRating > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(
                          5,
                          (i) => Padding(
                                padding: const EdgeInsets.only(right: 2),
                                child: Icon(
                                  i < comic.starRating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: i < comic.starRating
                                      ? AppColors.gold
                                      : Colors.white24,
                                  size: 13,
                                ),
                              )),
                    ),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ).animate().fadeIn(duration: 500.ms).scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.easeOutCubic),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LAYOUT 2 — SHELVES
// ══════════════════════════════════════════════════════════════════════════════

class _ShelvesLayout extends StatelessWidget {
  final List<Comic> all;
  final List<Comic> recentlyAdded;
  final List<Comic> continueReading;
  final List<Comic> topRated;
  final _LayoutCallbacks cb;

  const _ShelvesLayout({
    required this.all,
    required this.recentlyAdded,
    required this.continueReading,
    required this.topRated,
    required this.cb,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: cb.onRefresh,
      color: AppColors.textPrimary,
      backgroundColor: AppColors.surface2,
      strokeWidth: 2,
      displacement: 60,
      child: CustomScrollView(
        physics: const BottomBouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
              child: _PremiumHeader(
                  onSearch: cb.onSearchTap,
                  onScan: cb.onScanTap,
                  onMenu: cb.onMenuTap)),
          if (all.isEmpty)
            SliverFillRemaining(child: _EmptyState(onScanTap: cb.onScanTap))
          else
            SliverToBoxAdapter(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const SizedBox(height: 4),
                _ReadingProgressRibbon(all: all),
                if (recentlyAdded.isNotEmpty) ...[
                  _Shelf(
                    title: 'Recently Added',
                    comics: recentlyAdded,
                    onTap: cb.onComicTap,
                    shelfType: _ShelfType.recentlyAdded,
                  ),
                  const SizedBox(height: 36),
                ],
                if (continueReading.isNotEmpty) ...[
                  _Shelf(
                    title: 'Continue Reading',
                    comics: continueReading,
                    onTap: cb.onComicTap,
                    shelfType: _ShelfType.continueReading,
                  ),
                  const SizedBox(height: 36),
                ],
                if (topRated.isNotEmpty) ...[
                  _Shelf(
                    title: 'Top Rated',
                    comics: topRated,
                    onTap: cb.onComicTap,
                    shelfType: _ShelfType.topRated,
                  ),
                  const SizedBox(height: 36),
                ],
                const SizedBox(height: 90),
              ]),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LAYOUT 3 — MOSAIC
// ══════════════════════════════════════════════════════════════════════════════

class _MosaicLayout extends StatelessWidget {
  final List<Comic> all;
  final List<Comic> recentlyAdded;
  final List<Comic> continueReading;
  final List<Comic> topRated;
  final _LayoutCallbacks cb;

  const _MosaicLayout({
    required this.all,
    required this.recentlyAdded,
    required this.continueReading,
    required this.topRated,
    required this.cb,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: cb.onRefresh,
      color: AppColors.textPrimary,
      backgroundColor: AppColors.surface2,
      strokeWidth: 2,
      displacement: 60,
      child: CustomScrollView(
        physics: const BottomBouncingScrollPhysics(),
        slivers: [
          if (all.isEmpty) ...[
            SliverToBoxAdapter(
                child: _PremiumHeader(
                    onSearch: cb.onSearchTap,
                    onScan: cb.onScanTap,
                    onMenu: cb.onMenuTap)),
            SliverFillRemaining(child: _EmptyState(onScanTap: cb.onScanTap)),
          ] else ...[
            SliverToBoxAdapter(
                child: _MosaicHeader(
              all: all,
              onSearch: cb.onSearchTap,
              onMenu: cb.onMenuTap,
            )),
            SliverToBoxAdapter(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (recentlyAdded.isNotEmpty) ...[
                  _Shelf(
                    title: 'Recently Added',
                    comics: recentlyAdded,
                    onTap: cb.onComicTap,
                    shelfType: _ShelfType.recentlyAdded,
                  ),
                  const SizedBox(height: 36),
                ],
                if (continueReading.isNotEmpty) ...[
                  _Shelf(
                    title: 'Continue Reading',
                    comics: continueReading,
                    onTap: cb.onComicTap,
                    shelfType: _ShelfType.continueReading,
                  ),
                  const SizedBox(height: 36),
                ],
                if (topRated.isNotEmpty) ...[
                  _Shelf(
                    title: 'Top Rated',
                    comics: topRated,
                    onTap: cb.onComicTap,
                    shelfType: _ShelfType.topRated,
                  ),
                  const SizedBox(height: 36),
                ],
                const SizedBox(height: 90),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mosaic cover-grid header ──────────────────────────────────────────────────

class _MosaicHeader extends StatelessWidget {
  final List<Comic> all;
  final VoidCallback onSearch;
  final VoidCallback onMenu;

  const _MosaicHeader({
    required this.all,
    required this.onSearch,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final covers = all
        .where((c) => c.coverImageUrl != null)
        .take(12)
        .map((c) => c.coverImageUrl!)
        .toList();
    final unread = all.where((c) => !c.isRead).length;
    final series = all.map((c) => c.seriesName).toSet().length;

    return SizedBox(
      height: 320,
      child: Stack(fit: StackFit.expand, children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, childAspectRatio: 0.67),
          itemCount: covers.isEmpty ? 12 : covers.length,
          itemBuilder: (_, i) => covers.isEmpty
              ? const SkeletonBox.cover()
              : CachedNetworkImage(
                  imageUrl: covers[i],
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.15),
                  colorBlendMode: BlendMode.darken,
                  placeholder: (_, __) => const SkeletonBox.cover(),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.surface2),
                ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.6),
                AppColors.bg,
              ],
              stops: const [0.0, 0.52, 1.0],
            ),
          ),
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          child: _MosaicFloatingHeader(onSearch: onSearch, onMenu: onMenu),
        ),
        Positioned(
          bottom: 22, left: 22, right: 22,
          child: Row(children: [
            _mosaicStat('${all.length}', 'Comics'),
            const SizedBox(width: 28),
            _mosaicStat('$unread', 'Unread'),
            const SizedBox(width: 28),
            _mosaicStat('$series', 'Series'),
          ]),
        ),
      ]),
    );
  }

  Widget _mosaicStat(String v, String l) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v,
              style: tDisplay(32,
                  color: Colors.white,
                  weight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: -1.0)),
          Text(l,
              style: tUi(12,
                  color: Colors.white.withOpacity(0.5),
                  weight: FontWeight.w500)),
        ],
      );
}