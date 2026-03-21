// lib/REST API/screens/comic_detail_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/typography.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';

import '../../theme/app_colors.dart';
import '../../theme/models/comic.dart';
import '../../theme/services/database_service.dart';
import '../../theme/services/comic_vine_service.dart';
import '../../theme/services/cover_palette_service.dart';
import '../../theme/services/app_settings.dart';
import '../../theme/utils/haptics.dart';
import '../../../widgets/pressable.dart';
import '../../../widgets/star_rating_widget.dart';
import '../../../widgets/skeleton_box.dart';
import 'series_run_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

enum ComicDetailMode { owned, preview }

class ComicDetailScreen extends StatefulWidget {
  final Comic comic;
  final VoidCallback onUpdated;
  final ComicDetailMode mode;
  final bool fromBarcode;
  final String? barcode;
  final void Function(Map<String, dynamic> reportData)? onWrongComic;

  const ComicDetailScreen({
    super.key,
    required this.comic,
    required this.onUpdated,
    this.mode = ComicDetailMode.owned,
    this.fromBarcode = false,
    this.barcode,
    this.onWrongComic,
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

  void _openCoverZoom() {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _CoverZoomScreen(
          imageUrl: _comic.coverImageUrl!,
          heroTag: widget.mode == ComicDetailMode.owned
              ? 'cover-${_comic.id}'
              : 'shelf-${_comic.id}',
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
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
    final status =
        await DatabaseService.instance.checkComicStatus(_comic.comicVineId);
    if (!mounted) return;
    setState(() {
      _inLibrary  = status.inLibrary;
      _inWishlist = status.inWishlist;
      _checking   = false;
    });
    if (!status.inLibrary) {
      final enriched = await _enrichCredits(_comic);
      if (mounted && enriched != _comic) setState(() => _comic = enriched);
    }
  }

  // ── Owned actions ─────────────────────────────────────────────────────────

  Future<void> _toggleRead() async {
    AppHaptics.medium();
    final nowRead = !_comic.isRead;
    final u = nowRead
        ? _comic.copyWith(isRead: true, isReading: false, readDate: DateTime.now())
        : _comic.copyWith(isRead: false, clearReadDate: true);
    await DatabaseService.instance.updateComic(u);
    setState(() => _comic = u);
    widget.onUpdated();
  }

  Future<void> _toggleIsReading() async {
    AppHaptics.medium();
    final nowReading = !_comic.isReading;
    // Marking as reading clears the read state to avoid both being true.
    final u = nowReading
        ? _comic.copyWith(isReading: true, isRead: false, clearReadDate: true)
        : _comic.copyWith(isReading: false);
    await DatabaseService.instance.updateComic(u);
    setState(() => _comic = u);
    widget.onUpdated();
  }

  Future<void> _setCondition(String? condition) async {
    AppHaptics.select();
    final clearing = condition == _comic.condition;
    final u = clearing
        ? _comic.copyWith(clearCondition: true)
        : _comic.copyWith(condition: condition);
    await DatabaseService.instance.updateComic(u);
    setState(() => _comic = u);
    widget.onUpdated();
  }

  Future<void> _openNotesEditor() async {
    AppHaptics.light();
    final ctrl = TextEditingController(text: _comic.notes ?? '');
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotesBottomSheet(controller: ctrl),
    );
    if (saved == null || !mounted) return;
    final u = saved.trim().isEmpty
        ? _comic.copyWith(clearNotes: true)
        : _comic.copyWith(notes: saved.trim());
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

  Future<void> _openPriceEditor() async {
    AppHaptics.light();
    final ctrl = TextEditingController(
        text: _comic.purchasePrice != null
            ? _comic.purchasePrice!.toStringAsFixed(2)
            : '');
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PriceBottomSheet(controller: ctrl),
    );
    if (saved == null || !mounted) return;
    final parsed = double.tryParse(saved.trim());
    final u = (saved.trim().isEmpty || parsed == null)
        ? _comic.copyWith(clearPurchasePrice: true)
        : _comic.copyWith(purchasePrice: parsed);
    await DatabaseService.instance.updateComic(u);
    setState(() => _comic = u);
    widget.onUpdated();
  }

  Future<void> _openLoanEditor() async {
    AppHaptics.light();
    final ctrl = TextEditingController(text: _comic.loanedTo ?? '');
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LoanBottomSheet(controller: ctrl),
    );
    if (saved == null || !mounted) return;
    final u = saved.trim().isEmpty
        ? _comic.copyWith(clearLoanedTo: true)
        : _comic.copyWith(loanedTo: saved.trim());
    await DatabaseService.instance.updateComic(u);
    setState(() => _comic = u);
    widget.onUpdated();
  }

  Future<void> _returnLoan() async {
    AppHaptics.medium();
    final u = _comic.copyWith(clearLoanedTo: true);
    await DatabaseService.instance.updateComic(u);
    setState(() => _comic = u);
    widget.onUpdated();
  }

  Future<void> _setTags(List<String> tags) async {
    final joined = tags.join(',');
    final u = tags.isEmpty
        ? _comic.copyWith(clearTags: true)
        : _comic.copyWith(tags: joined);
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
            Text('Remove from Vault', style: tUi(17, weight: FontWeight.w700)),
        content: Text(
          'This will permanently remove this comic from your library.',
          style: tUi(14,
              color: AppColors.textSecondary,
              weight: FontWeight.w400,
              height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: tUi(14,
                    color: AppColors.textSecondary,
                    weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: tUi(14,
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

  Future<void> _removeFromLibrary() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove from Library', style: tUi(17, weight: FontWeight.w700)),
        content: Text(
          'This will remove the comic from your library.',
          style: tUi(14, color: AppColors.textSecondary, weight: FontWeight.w400, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: tUi(14, color: AppColors.textSecondary, weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: tUi(14, color: AppColors.redDestructive, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    AppHaptics.heavy();
    final saved = await DatabaseService.instance.getComicByVineId(_comic.comicVineId);
    if (saved?.id != null) await DatabaseService.instance.deleteComic(saved!.id!);
    if (!mounted) return;
    setState(() => _inLibrary = false);
    widget.onUpdated();
    _snack('Removed from library');
  }

  Future<void> _addToLibrary() async {
    if (_inLibrary) { _removeFromLibrary(); return; }
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
        Text(msg, style: tUi(13, color: AppColors.textPrimary)),
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
                  color: Colors.white, size: 16,
                  semanticLabel: 'Back'),
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
                  child: Pressable(
                    onTap: _comic.coverImageUrl != null ? _openCoverZoom : null,
                    haptic: HapticStyle.light,
                    scaleDown: 0.97,
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
                  style: tUi(13,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w500),
                ).animate().fadeIn(delay: 80.ms),

              const SizedBox(height: 7),

              Text(
                _comic.title,
                style: tDisplay(30,
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
                      style: tUi(13,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w400)),
                if (_comic.publisher != null &&
                    _comic.publicationYear != null)
                  Text('  ·  ',
                      style: tUi(13,
                          color: AppColors.textTertiary)),
                if (_comic.publicationYear != null)
                  Text('${_comic.publicationYear}',
                      style: tUi(13,
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

              if (widget.mode == ComicDetailMode.owned) ...[
                _conditionSection(),
                const SizedBox(height: 24),
                Divider(color: AppColors.border.withOpacity(0.6), height: 1),
                const SizedBox(height: 24),
                _purchasePriceSection(),
                const SizedBox(height: 24),
                Divider(color: AppColors.border.withOpacity(0.6), height: 1),
                const SizedBox(height: 24),
                _tagsSection(),
                const SizedBox(height: 24),
                Divider(color: AppColors.border.withOpacity(0.6), height: 1),
                const SizedBox(height: 24),
                _loanSection(),
                const SizedBox(height: 24),
                Divider(color: AppColors.border.withOpacity(0.6), height: 1),
                const SizedBox(height: 24),
                _notesSection(),
                const SizedBox(height: 24),
                Divider(color: AppColors.border.withOpacity(0.6), height: 1),
                const SizedBox(height: 24),
              ],

              if (_comic.description != null &&
                  _comic.description!.isNotEmpty) ...[
                Text('SYNOPSIS',
                    style: tUi(10,
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
                      style: tUi(15,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w400,
                          height: 1.7),
                    ),
                    secondChild: Text(
                      _comic.description!,
                      style: tUi(15,
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
                      style: tUi(13,
                          color: AppColors.accent,
                          weight: FontWeight.w600),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      _descExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.accent,
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
      if (widget.mode == ComicDetailMode.owned) ...[
        const SizedBox(height: 10),
        _isReadingBtn().animate().fadeIn(delay: 220.ms),
      ],
      const SizedBox(height: 10),
      if (_comic.volumeId != null)
        _fullRunBtn().animate().fadeIn(delay: 230.ms),
      if (widget.fromBarcode) ...[
        const SizedBox(height: 10),
        _wrongComicBtn().animate().fadeIn(delay: 260.ms),
      ],
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
                ? AppColors.greenOwnedDim
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _comic.isRead
                    ? AppColors.green_(0.4)
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
                      ? AppColors.greenOwned
                      : AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _comic.isRead ? 'Read' : 'Mark as Read',
                  style: tUi(14,
                      color: _comic.isRead
                          ? AppColors.greenOwned
                          : AppColors.textSecondary,
                      weight: FontWeight.w700),
                ),
              ]),
        ),
      );
    } else {
      return Pressable(
        onTap: _addToLibrary,
        haptic: HapticStyle.none,
        scaleDown: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          height: 52,
          decoration: BoxDecoration(
            color: _inLibrary ? AppColors.surface2 : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _inLibrary ? AppColors.border : Colors.transparent),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _inLibrary ? Icons.remove_circle_outline_rounded : Icons.add_rounded,
                  color: _inLibrary ? AppColors.redDestructive.withOpacity(0.8) : AppColors.bg,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _inLibrary ? 'Remove from Library' : 'Add to Library',
                  style: tUi(14,
                      color: _inLibrary
                          ? AppColors.redDestructive.withOpacity(0.8)
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

  Widget _isReadingBtn() => Pressable(
        onTap: _toggleIsReading,
        haptic: HapticStyle.none,
        scaleDown: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          height: 52,
          decoration: BoxDecoration(
            color: _comic.isReading ? AppColors.surface2 : AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _comic.isReading
                  ? AppColors.greenOwned.withOpacity(0.5)
                  : AppColors.border,
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              _comic.isReading
                  ? Icons.menu_book_rounded
                  : Icons.menu_book_outlined,
              color: _comic.isReading
                  ? AppColors.greenOwned
                  : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _comic.isReading ? 'Currently Reading' : 'Mark as Reading',
              style: tUi(14,
                  color: _comic.isReading
                      ? AppColors.greenOwned
                      : AppColors.textSecondary,
                  weight: FontWeight.w600),
            ),
          ]),
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
                    color: AppColors.accent, size: 17),
                const SizedBox(width: 8),
                Text('View Full Run',
                    style: tUi(14,
                        color: AppColors.textSecondary,
                        weight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.accent, size: 17),
              ]),
        ),
      );

  Widget _wrongComicBtn() => Pressable(
        onTap: _reportWrongComic,
        haptic: HapticStyle.light,
        scaleDown: 0.97,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.flag_outlined, color: AppColors.textTertiary, size: 16),
            const SizedBox(width: 8),
            Text('Wrong comic? Report it',
                style: tUi(13,
                    color: AppColors.textTertiary, weight: FontWeight.w500)),
          ]),
        ),
      );

  Future<void> _reportWrongComic() async {
    final noteCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Report Wrong Comic', style: tUi(17, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode scanned',
                style: tUi(11, color: AppColors.textTertiary, weight: FontWeight.w500, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(widget.barcode ?? '—',
                style: tUi(13, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            Text('Returned as',
                style: tUi(11, color: AppColors.textTertiary, weight: FontWeight.w500, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text('${_comic.seriesName} #${_comic.issueNumber ?? "?"} — ${_comic.title}',
                style: tUi(13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              style: tUi(13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Any extra details? (optional)',
                hintStyle: tUi(13, color: AppColors.textTertiary, weight: FontWeight.w400),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: tUi(14, color: AppColors.textSecondary, weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Submit Report',
                style: tUi(14, color: AppColors.textPrimary, weight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (submitted != true || !mounted) return;
    final reportData = await _saveReport(noteCtrl.text.trim());
    _snack('Report sent. Pick the correct comic below.',
        icon: Icons.check_circle_outline_rounded);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.pop(context);
    widget.onWrongComic?.call(reportData);
  }

  static const String _reportWebhookUrl =
      String.fromEnvironment('DISCORD_WEBHOOK_URL', defaultValue: '');

  Future<Map<String, dynamic>> _saveReport(String note) async {
    final timestamp = DateTime.now().toIso8601String();
    final comicLabel =
        '${_comic.seriesName} #${_comic.issueNumber ?? "?"} — ${_comic.title}';

    final reportData = {
      'timestamp': timestamp,
      'barcode': widget.barcode ?? '',
      'wrongComic': {
        'comicVineId': _comic.comicVineId,
        'title': _comic.title,
        'seriesName': _comic.seriesName,
        'issueNumber': _comic.issueNumber ?? '',
      },
      'note': note,
      'wrongComicLabel': comicLabel,
    };

    // Always persist locally
    final prefs = await SharedPreferences.getInstance();
    final log = prefs.getStringList('barcode_mismatch_reports') ?? [];
    log.add(json.encode(reportData));
    await prefs.setStringList('barcode_mismatch_reports', log);

    // POST to Discord webhook
    try {
      final fields = <Map<String, dynamic>>[
        {'name': 'Barcode', 'value': widget.barcode ?? '—', 'inline': true},
        {'name': 'Returned as', 'value': comicLabel, 'inline': false},
        if (note.isNotEmpty) {'name': 'User note', 'value': note, 'inline': false},
      ];

      await http
          .post(
            Uri.parse(_reportWebhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'embeds': [
                {
                  'title': '🚩 Wrong Comic Report',
                  'color': 0xE74C3C,
                  'fields': fields,
                  'footer': {'text': 'Comic Vault'},
                  'timestamp': timestamp,
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}

    return reportData;
  }

  static const _conditions = ['NM', 'VF', 'FN', 'VG', 'G', 'FR'];
  static const _conditionLabels = {
    'NM': 'Near Mint',
    'VF': 'Very Fine',
    'FN': 'Fine',
    'VG': 'Very Good',
    'G': 'Good',
    'FR': 'Fair',
  };

  Widget _conditionSection() => Column(
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
              final selected = _comic.condition == grade;
              return Pressable(
                onTap: () => _setCondition(grade),
                haptic: HapticStyle.light,
                scaleDown: 0.92,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

  Widget _notesSection() => Column(
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
              onTap: _openNotesEditor,
              haptic: HapticStyle.light,
              child: Text(
                _comic.notes == null ? 'Add' : 'Edit',
                style: tUi(12,
                    color: AppColors.textTertiary, weight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Pressable(
            onTap: _openNotesEditor,
            haptic: HapticStyle.light,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _comic.notes != null
                  ? Text(_comic.notes!,
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

  Widget _purchasePriceSection() {
    final price = _comic.purchasePrice;
    return Column(
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
            onTap: _openPriceEditor,
            haptic: HapticStyle.light,
            child: Text(
              price == null ? 'Add' : 'Edit',
              style: tUi(12, color: AppColors.textTertiary, weight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Pressable(
          onTap: _openPriceEditor,
          haptic: HapticStyle.light,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: price != null
                ? Row(children: [
                    Text(AppSettings.instance.currencySymbol,
                        style: tUi(15,
                            color: AppColors.greenOwned,
                            weight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Text(price.toStringAsFixed(2),
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

  static const _suggestedTags = [
    'Key Issue', 'First Appearance', 'Signed', 'CGC Graded',
    'Variant Cover', '1st Print', 'Newsstand',
  ];

  Widget _tagsSection() {
    final currentTags = _comic.tagList;
    return Column(
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
            ...currentTags.map((tag) => Pressable(
              onTap: () {
                AppHaptics.light();
                final updated = [...currentTags]..remove(tag);
                _setTags(updated);
              },
              haptic: HapticStyle.none,
              scaleDown: 0.92,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                .where((t) => !currentTags.contains(t))
                .map((tag) => Pressable(
              onTap: () {
                AppHaptics.light();
                _setTags([...currentTags, tag]);
              },
              haptic: HapticStyle.none,
              scaleDown: 0.92,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
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

  Widget _loanSection() {
    final loaned = _comic.loanedTo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LOAN',
            style: tUi(10,
                color: AppColors.textTertiary,
                weight: FontWeight.w700,
                letterSpacing: 1.6)),
        const SizedBox(height: 12),
        if (loaned != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.goldDim,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold_(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.person_rounded, color: AppColors.gold, size: 18),
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
                    Text(loaned,
                        style: tUi(14,
                            color: AppColors.textPrimary,
                            weight: FontWeight.w600)),
                  ],
                ),
              ),
              Pressable(
                onTap: _returnLoan,
                haptic: HapticStyle.medium,
                scaleDown: 0.92,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
            onTap: _openLoanEditor,
            haptic: HapticStyle.light,
            child: Text('Edit name',
                style: tUi(12,
                    color: AppColors.textTertiary, weight: FontWeight.w500)),
          ),
        ] else
          Pressable(
            onTap: _openLoanEditor,
            haptic: HapticStyle.light,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
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

  Widget _creditRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label,
                style: tUi(12,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: tUi(13,
                    color: AppColors.textSecondary,
                    weight: FontWeight.w500,
                    height: 1.45)),
          ),
        ],
      ).animate().fadeIn(delay: 260.ms);
}

// ── Cover zoom screen ─────────────────────────────────────────────────────────

class _CoverZoomScreen extends StatelessWidget {
  final String imageUrl;
  final Object heroTag;
  const _CoverZoomScreen({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black87,
          child: Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(
                    color: Colors.white38,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Price bottom sheet ────────────────────────────────────────────────────────

class _PriceBottomSheet extends StatefulWidget {
  final TextEditingController controller;
  const _PriceBottomSheet({required this.controller});

  @override
  State<_PriceBottomSheet> createState() => _PriceBottomSheetState();
}

class _PriceBottomSheetState extends State<_PriceBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Purchase Price', style: tUi(17, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('What did you pay for this comic?',
              style: tUi(13, color: AppColors.textTertiary, weight: FontWeight.w400)),
          const SizedBox(height: 14),
          TextField(
            controller: widget.controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: tUi(16, color: AppColors.textPrimary, weight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: tUi(16, color: AppColors.textTertiary),
              helperText: 'Enter amount in your local currency',
              helperStyle: tUi(11, color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surface3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.45)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Pressable(
                onTap: () => Navigator.pop(context),
                haptic: HapticStyle.select,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(child: Text('Cancel',
                      style: tUi(14, color: AppColors.textSecondary, weight: FontWeight.w600))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Pressable(
                onTap: () => Navigator.pop(context, widget.controller.text),
                haptic: HapticStyle.medium,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text('Save',
                      style: tUi(14, color: AppColors.bg, weight: FontWeight.w700))),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Loan bottom sheet ─────────────────────────────────────────────────────────

class _LoanBottomSheet extends StatefulWidget {
  final TextEditingController controller;
  const _LoanBottomSheet({required this.controller});

  @override
  State<_LoanBottomSheet> createState() => _LoanBottomSheetState();
}

class _LoanBottomSheetState extends State<_LoanBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Loan Out', style: tUi(17, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Who are you loaning this to?',
              style: tUi(13, color: AppColors.textTertiary, weight: FontWeight.w400)),
          const SizedBox(height: 14),
          TextField(
            controller: widget.controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: tUi(14, color: AppColors.textPrimary, weight: FontWeight.w400),
            decoration: InputDecoration(
              hintText: 'Person\'s name…',
              hintStyle: tUi(14, color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.person_outlined,
                  color: AppColors.textSecondary, size: 20),
              filled: true,
              fillColor: AppColors.surface3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.45)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Pressable(
                onTap: () => Navigator.pop(context),
                haptic: HapticStyle.select,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(child: Text('Cancel',
                      style: tUi(14, color: AppColors.textSecondary, weight: FontWeight.w600))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Pressable(
                onTap: () => Navigator.pop(context, widget.controller.text),
                haptic: HapticStyle.medium,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text('Loan Out',
                      style: tUi(14, color: AppColors.bg, weight: FontWeight.w700))),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Notes bottom sheet ────────────────────────────────────────────────────────

class _NotesBottomSheet extends StatefulWidget {
  final TextEditingController controller;
  const _NotesBottomSheet({required this.controller});

  @override
  State<_NotesBottomSheet> createState() => _NotesBottomSheetState();
}

class _NotesBottomSheetState extends State<_NotesBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Notes', style: tUi(17, weight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: widget.controller,
            autofocus: true,
            maxLines: 6,
            style: tUi(14,
                color: AppColors.textPrimary,
                weight: FontWeight.w400,
                height: 1.6),
            decoration: InputDecoration(
              hintText: 'Your thoughts on this issue…',
              hintStyle: tUi(14,
                  color: AppColors.textDisabled, weight: FontWeight.w400),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderFocus),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Pressable(
                onTap: () => Navigator.pop(context),
                haptic: HapticStyle.select,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text('Cancel',
                        style: tUi(14,
                            color: AppColors.textSecondary,
                            weight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Pressable(
                onTap: () =>
                    Navigator.pop(context, widget.controller.text),
                haptic: HapticStyle.medium,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text('Save',
                        style: tUi(14,
                            color: AppColors.bg,
                            weight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}