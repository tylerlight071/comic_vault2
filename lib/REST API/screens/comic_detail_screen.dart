// lib/REST API/screens/comic_detail_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';

import '../../theme/app_colors.dart';
import '../../theme/models/comic.dart';
import '../../theme/services/database_service.dart';
import '../../theme/services/comic_vine_service.dart';
import '../../theme/services/cover_palette_service.dart';
import '../../theme/utils/haptics.dart';
import '../../../widgets/pressable.dart';
import '../../../widgets/star_rating_widget.dart';
import '../../../widgets/skeleton_box.dart';
import 'series_run_screen.dart';

// ── Typography helpers ────────────────────────────────────────────────────────

TextStyle _display(double size,
        {Color? color,
        FontWeight weight = FontWeight.w700,
        double? height,
        double letterSpacing = -0.5}) =>
    GoogleFonts.playfairDisplay(
      color: color ?? AppColors.textPrimary,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );

TextStyle _ui(double size,
        {Color? color,
        FontWeight weight = FontWeight.w500,
        double? height,
        double letterSpacing = 0}) =>
    GoogleFonts.dmSans(
      color: color ?? AppColors.textPrimary,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );

// ─────────────────────────────────────────────────────────────────────────────

enum ComicDetailMode { owned, preview }

class ComicDetailScreen extends StatefulWidget {
  final Comic comic;
  final VoidCallback onUpdated;
  final ComicDetailMode mode;

  const ComicDetailScreen({
    super.key,
    required this.comic,
    required this.onUpdated,
    this.mode = ComicDetailMode.owned,
  });

  @override
  State<ComicDetailScreen> createState() => _ComicDetailScreenState();
}

class _ComicDetailScreenState extends State<ComicDetailScreen> {
  late Comic _comic;
  bool _descExpanded = false;
  bool _inLibrary    = false;
  bool _inWishlist   = false;
  bool _checking     = true;

  Color _paletteColor = AppColors.bg;

  @override
  void initState() {
    super.initState();
    _comic = widget.comic;
    _loadPalette();
    if (widget.mode == ComicDetailMode.preview) {
      _checkStatus();
    } else {
      _checking = false;
    }
  }

  // ── Palette ───────────────────────────────────────────────────────────────

  Future<void> _loadPalette() async {
    final color =
        await CoverPaletteService.instance.getColor(_comic.coverImageUrl);
    if (mounted) setState(() => _paletteColor = color);
  }

  // ── Credit enrichment ─────────────────────────────────────────────────────

  Future<Comic> _enrichCredits(Comic comic) async {
    if (comic.writers != null || comic.artists != null) return comic;
    try {
      final fresh =
          await ComicVineService.instance.fetchIssueById(comic.comicVineId);
      if (fresh == null) return comic;
      return comic.copyWith(
        writers: fresh.writers,
        artists: fresh.artists,
        description: comic.description ?? fresh.description,
      );
    } catch (_) {
      return comic;
    }
  }

  // ── Status check (preview mode) ───────────────────────────────────────────

  Future<void> _checkStatus() async {
    final owned =
        await DatabaseService.instance.comicExists(_comic.comicVineId);
    final wish =
        await DatabaseService.instance.isOnWishlist(_comic.comicVineId);
    if (!mounted) return;
    setState(() {
      _inLibrary = owned;
      _inWishlist = wish;
      _checking = false;
    });
    if (!owned) {
      final enriched = await _enrichCredits(_comic);
      if (mounted && enriched != _comic) setState(() => _comic = enriched);
    }
  }

  // ── Owned actions ─────────────────────────────────────────────────────────

  Future<void> _toggleRead() async {
    AppHaptics.medium();
    final u = _comic.copyWith(isRead: !_comic.isRead);
    await DatabaseService.instance.updateComic(u);
    setState(() => _comic = u);
    widget.onUpdated();
  }

  Future<void> _setRating(int r) async {
    AppHaptics.select();
    final u = _comic.copyWith(starRating: r);
    await DatabaseService.instance.updateComic(u);
    setState(() => _comic = u);
    widget.onUpdated();
  }

  Future<void> _delete() async {
    AppHaptics.warning();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('Remove from Vault', style: _ui(17, weight: FontWeight.w700)),
        content: Text(
          'This will permanently remove this comic from your library.',
          style: _ui(14,
              color: AppColors.textSecondary,
              weight: FontWeight.w400,
              height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: _ui(14,
                    color: AppColors.textSecondary,
                    weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: _ui(14,
                    color: AppColors.redDestructive,
                    weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && _comic.id != null) {
      AppHaptics.heavy();
      await DatabaseService.instance.deleteComic(_comic.id!);
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Preview actions ───────────────────────────────────────────────────────

  Future<void> _addToLibrary() async {
    if (_inLibrary) return;
    AppHaptics.success();
    if (_inWishlist) {
      await DatabaseService.instance
          .moveWishlistToLibrary(_comic.comicVineId);
      if (_comic.writers != null || _comic.artists != null) {
        final saved = await DatabaseService.instance
            .getComicByVineId(_comic.comicVineId);
        if (saved != null) {
          await DatabaseService.instance.updateComic(
            saved.copyWith(
                writers: _comic.writers, artists: _comic.artists),
          );
        }
      }
    } else {
      await DatabaseService.instance.insertComic(_comic);
    }
    setState(() {
      _inLibrary = true;
      _inWishlist = false;
    });
    widget.onUpdated();
    _snack('Added to your vault', icon: Icons.library_add_check_rounded);
  }

  Future<void> _toggleWishlist() async {
    if (_inLibrary) return;
    AppHaptics.light();
    if (_inWishlist) {
      await DatabaseService.instance
          .removeFromWishlist(_comic.comicVineId);
      setState(() => _inWishlist = false);
      _snack('Removed from wishlist');
    } else {
      await DatabaseService.instance.addToWishlist(_comic);
      setState(() => _inWishlist = true);
      widget.onUpdated();
      _snack('Added to wishlist', icon: Icons.bookmark_added_rounded);
    }
  }

  void _openSeriesRun() {
    final vid = _comic.volumeId;
    if (vid == null || vid.isEmpty) {
      _snack('No series data available');
      return;
    }
    AppHaptics.select();
    Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => SeriesRunScreen(
              seriesName: _comic.seriesName,
              volumeId: vid,
              onChanged: widget.onUpdated),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 280),
        ));
  }

  void _snack(String msg, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
        ],
        Text(msg, style: _ui(13, color: AppColors.textPrimary)),
      ]),
      backgroundColor: AppColors.snackbar,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: CustomScrollView(
        physics: const BottomBouncingScrollPhysics(),
        slivers: [_buildHero(), _buildInfo()],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar() => AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Pressable(
            onTap: () => Navigator.pop(context),
            haptic: HapticStyle.select,
            scaleDown: 0.88,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ),
        actions: [
          if (widget.mode == ComicDetailMode.owned)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 10),
              child: Pressable(
                onTap: _delete,
                haptic: HapticStyle.none,
                scaleDown: 0.88,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppColors.redDestructive.withOpacity(0.85),
                      size: 17),
                ),
              ),
            ),
        ],
      );

  // ── Cinematic hero ────────────────────────────────────────────────────────
  //
  // Raster optimisations applied:
  //
  //   1. Removed colorBlendMode: BlendMode.darken from the backdrop image.
  //      That flag forces an implicit saveLayer (offscreen compositing buffer)
  //      which is one of the most expensive raster operations in Flutter and
  //      was causing 5 consecutive frames over budget during the hero entry.
  //      Darkening is now a plain semi-transparent black Container layered on
  //      top — identical visual result, zero saveLayer cost.
  //
  //   2. BoxShadow reduced from two entries to one. Each shadow requires a
  //      separate blur pass on the GPU. The colour-matched glow is kept with
  //      slightly higher opacity to compensate for the removed hard shadow.
  //
  //   3. RepaintBoundary wraps the Hero widget so its animation repaints are
  //      isolated and don't invalidate the surrounding stack layers.

  Widget _buildHero() => SliverToBoxAdapter(
        child: SizedBox(
          height: 500,
          child: Stack(fit: StackFit.expand, children: [
            // 1. Backdrop image — no colorBlendMode, no saveLayer
            if (_comic.coverImageUrl != null)
              CachedNetworkImage(
                imageUrl: _comic.coverImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppColors.surface2),
              )
            else
              Container(color: AppColors.surface2),

            // 2. Darkening overlay — replaces BlendMode.darken
            Container(color: Colors.black.withOpacity(0.52)),

            // 3. Palette ambient wash
            AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _paletteColor.withOpacity(0.50),
                    _paletteColor.withOpacity(0.22),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.38, 0.72],
                ),
              ),
            ),

            // 4. Bottom gradient — always ends at AppColors.bg
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    AppColors.bg,
                  ],
                  stops: const [0.25, 0.62, 1.0],
                ),
              ),
            ),

            // 5. Floating cover art — single shadow, RepaintBoundary
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Center(
                child: RepaintBoundary(
                  child: Hero(
                    tag: widget.mode == ComicDetailMode.owned
                        ? 'cover-${_comic.id}'
                        : 'shelf-${_comic.id}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      width: 190,
                      height: 286,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _paletteColor.withOpacity(0.60),
                            blurRadius: 48,
                            spreadRadius: 6,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _comic.coverImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _comic.coverImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    const SkeletonBox.cover(),
                              )
                            : Container(
                                color: AppColors.surface2,
                                child: const Center(
                                  child: Icon(Icons.menu_book_rounded,
                                      color: AppColors.textDisabled,
                                      size: 64),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );

  // ── Info section ──────────────────────────────────────────────────────────

  Widget _buildInfo() => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_comic.issueNumber != null ||
                  _comic.seriesName.isNotEmpty)
                Text(
                  [
                    _comic.seriesName,
                    if (_comic.issueNumber != null)
                      '#${_comic.issueNumber}',
                  ].join('  ·  '),
                  style: _ui(13,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w500),
                ).animate().fadeIn(delay: 80.ms),

              const SizedBox(height: 7),

              Text(
                _comic.title,
                style: _display(30,
                    weight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: -0.6),
              )
                  .animate()
                  .fadeIn(delay: 120.ms)
                  .slideY(begin: 0.06, end: 0),

              const SizedBox(height: 10),

              Row(children: [
                if (_comic.publisher != null)
                  Text(_comic.publisher!,
                      style: _ui(13,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w400)),
                if (_comic.publisher != null &&
                    _comic.publicationYear != null)
                  Text('  ·  ',
                      style: _ui(13,
                          color: AppColors.textTertiary)),
                if (_comic.publicationYear != null)
                  Text('${_comic.publicationYear}',
                      style: _ui(13,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w400)),
              ]).animate().fadeIn(delay: 155.ms),

              const SizedBox(height: 30),

              _buildActions(),

              const SizedBox(height: 30),

              Divider(
                  color: AppColors.border.withOpacity(0.6), height: 1),

              const SizedBox(height: 24),

              if (_comic.writers != null)
                _creditRow('Written by', _comic.writers!),
              if (_comic.writers != null && _comic.artists != null)
                const SizedBox(height: 12),
              if (_comic.artists != null)
                _creditRow('Art by', _comic.artists!),

              if (_comic.writers != null || _comic.artists != null) ...[
                const SizedBox(height: 24),
                Divider(
                    color: AppColors.border.withOpacity(0.6),
                    height: 1),
                const SizedBox(height: 24),
              ],

              if (_comic.description != null &&
                  _comic.description!.isNotEmpty) ...[
                Text('SYNOPSIS',
                    style: _ui(10,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w700,
                        letterSpacing: 1.6)),
                const SizedBox(height: 12),
                Pressable(
                  onTap: () =>
                      setState(() => _descExpanded = !_descExpanded),
                  haptic: HapticStyle.light,
                  child: AnimatedCrossFade(
                    firstChild: Text(
                      _comic.description!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: _ui(15,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w400,
                          height: 1.7),
                    ),
                    secondChild: Text(
                      _comic.description!,
                      style: _ui(15,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w400,
                          height: 1.7),
                    ),
                    crossFadeState: _descExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                ),
                const SizedBox(height: 8),
                Pressable(
                  onTap: () =>
                      setState(() => _descExpanded = !_descExpanded),
                  haptic: HapticStyle.light,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      _descExpanded ? 'Show less' : 'Read more',
                      style: _ui(13,
                          color: AppColors.textTertiary,
                          weight: FontWeight.w600),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      _descExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textTertiary,
                      size: 16,
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      );

  // ── Actions ───────────────────────────────────────────────────────────────

  Widget _buildActions() {
    if (_checking) {
      return SizedBox(
        height: 52,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.textTertiary.withOpacity(0.5),
            strokeWidth: 1.5,
          ),
        ),
      );
    }
    return Column(children: [
      Row(children: [
        Expanded(flex: 3, child: _primaryActionBtn()),
        const SizedBox(width: 10),
        if (widget.mode == ComicDetailMode.owned)
          _starBox()
        else
          _wishlistBtn(),
      ]).animate().fadeIn(delay: 200.ms),
      const SizedBox(height: 10),
      if (_comic.volumeId != null)
        _fullRunBtn().animate().fadeIn(delay: 230.ms),
    ]);
  }

  Widget _primaryActionBtn() {
    if (widget.mode == ComicDetailMode.owned) {
      return Pressable(
        onTap: _toggleRead,
        haptic: HapticStyle.none,
        scaleDown: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          height: 52,
          decoration: BoxDecoration(
            color: _comic.isRead
                ? AppColors.textPrimary
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _comic.isRead
                    ? Colors.transparent
                    : AppColors.border),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _comic.isRead
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: _comic.isRead
                      ? AppColors.bg
                      : AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _comic.isRead ? 'Read' : 'Mark as Read',
                  style: _ui(14,
                      color: _comic.isRead
                          ? AppColors.bg
                          : AppColors.textSecondary,
                      weight: FontWeight.w700),
                ),
              ]),
        ),
      );
    } else {
      return Pressable(
        onTap: _inLibrary ? null : _addToLibrary,
        haptic: HapticStyle.none,
        scaleDown: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          height: 52,
          decoration: BoxDecoration(
            color: _inLibrary
                ? AppColors.surface2
                : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _inLibrary
                    ? AppColors.border
                    : Colors.transparent),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _inLibrary
                      ? Icons.check_circle_rounded
                      : Icons.add_rounded,
                  color: _inLibrary
                      ? AppColors.textTertiary
                      : AppColors.bg,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _inLibrary ? 'In Library' : 'Add to Library',
                  style: _ui(14,
                      color: _inLibrary
                          ? AppColors.textTertiary
                          : AppColors.bg,
                      weight: FontWeight.w700),
                ),
              ]),
        ),
      );
    }
  }

  Widget _starBox() => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: StarRatingWidget(
              rating: _comic.starRating,
              onRated: _setRating,
              size: 24),
        ),
      );

  Widget _wishlistBtn() => Pressable(
        onTap: _inLibrary ? null : _toggleWishlist,
        haptic: HapticStyle.none,
        scaleDown: 0.9,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color:
                _inWishlist ? AppColors.goldDim : AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _inWishlist
                    ? AppColors.gold_(0.4)
                    : AppColors.border),
          ),
          child: Icon(
            _inWishlist
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color:
                _inWishlist ? AppColors.gold : AppColors.textSecondary,
            size: 22,
          ),
        ),
      );

  Widget _fullRunBtn() => Pressable(
        onTap: _openSeriesRun,
        haptic: HapticStyle.none,
        scaleDown: 0.97,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.format_list_numbered_rounded,
                    color: AppColors.textSecondary, size: 17),
                const SizedBox(width: 8),
                Text('View Full Run',
                    style: _ui(14,
                        color: AppColors.textSecondary,
                        weight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary, size: 17),
              ]),
        ),
      );

  Widget _creditRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label,
                style: _ui(12,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: _ui(13,
                    color: AppColors.textSecondary,
                    weight: FontWeight.w500,
                    height: 1.45)),
          ),
        ],
      ).animate().fadeIn(delay: 260.ms);
}