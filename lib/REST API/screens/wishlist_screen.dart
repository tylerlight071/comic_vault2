// lib/REST API/screens/wishlist_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';

import '../../theme/app_colors.dart';
import '../../theme/models/comic.dart';
import '../../theme/services/cover_palette_service.dart';
import '../../theme/services/database_service.dart';
import '../../theme/utils/haptics.dart';
import '../../../widgets/pressable.dart';
import 'comic_detail_screen.dart';

// ── Typography ────────────────────────────────────────────────────────────────

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

// ── Screen ────────────────────────────────────────────────────────────────────

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Comic> _items = [];
  bool _loading = true;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (_searchCtrl.text != _query) {
        setState(() => _query = _searchCtrl.text);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await DatabaseService.instance.getWishlist();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _remove(Comic comic) async {
    AppHaptics.medium();
    await DatabaseService.instance.removeFromWishlist(comic.comicVineId);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Removed from wishlist',
            style: _ui(13, color: AppColors.textPrimary)),
        backgroundColor: AppColors.snackbar,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.textSecondary,
          onPressed: () async {
            await DatabaseService.instance.addToWishlist(comic);
            _load();
          },
        ),
      ));
    }
  }

  void _openDetail(Comic comic) {
    AppHaptics.light();
    Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ComicDetailScreen(
              comic: comic,
              onUpdated: _load,
              mode: ComicDetailMode.preview),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 260),
        ));
  }

  List<Comic> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where((c) =>
            c.seriesName.toLowerCase().contains(q) ||
            c.title.toLowerCase().contains(q) ||
            (c.issueNumber?.toLowerCase().contains(q) ?? false) ||
            (c.publisher?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BottomBouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          if (_loading)
            _buildShimmer()
          else if (_items.isEmpty)
            _buildEmpty()
          else ...[
            _buildSearchBar(),
            if (filtered.isEmpty)
              _buildNoResults()
            else
              _buildList(filtered),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() => SliverAppBar(
        pinned: true,
        backgroundColor: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: AppColors.border.withOpacity(0.5)),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Pressable(
            onTap: () => Navigator.pop(context),
            haptic: HapticStyle.select,
            scaleDown: 0.88,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.textSecondary, size: 16),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SAVED ISSUES',
                style: _ui(10,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Wishlist',
                    style: _display(17,
                        weight: FontWeight.w700, letterSpacing: -0.4)),
                if (_items.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text('${_items.length}',
                      style: _ui(11,
                          color: AppColors.textTertiary,
                          weight: FontWeight.w400)),
                ],
              ],
            ),
          ],
        ),
      );

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() => SliverToBoxAdapter(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded,
                    color: AppColors.textTertiary, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: _ui(14, weight: FontWeight.w400),
                    cursorColor: AppColors.textSecondary,
                    cursorWidth: 1.5,
                    decoration: InputDecoration(
                      hintText: 'Search wishlist…',
                      hintStyle: _ui(14,
                          color: AppColors.textDisabled,
                          weight: FontWeight.w400),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  Pressable(
                    onTap: () {
                      AppHaptics.light();
                      _searchCtrl.clear();
                    },
                    haptic: HapticStyle.none,
                    scaleDown: 0.85,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.close_rounded,
                          color: AppColors.textTertiary, size: 15),
                    ),
                  ),
              ]),
            ),
          ),
          Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
        ]),
      );

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList(List<Comic> items) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => Dismissible(
              key: Key(items[i].comicVineId),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.red_(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.red_(0.25)),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.redDestructive, size: 22),
              ),
              onDismissed: (_) => _remove(items[i]),
              child: _WishlistCard(
                comic: items[i],
                onTap: () => _openDetail(items[i]),
                onRemove: () => _remove(items[i]),
              )
                  .animate(
                      delay: Duration(
                          milliseconds: (i * 40).clamp(0, 400)))
                  .fadeIn(duration: 280.ms)
                  .slideX(
                      begin: 0.03,
                      end: 0,
                      curve: Curves.easeOutCubic),
            ),
            childCount: items.length,
          ),
        ),
      );

  // ── Shimmer ───────────────────────────────────────────────────────────────

  Widget _buildShimmer() => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => const _SkeletonWishlistCard()
                .animate(
                  delay: Duration(milliseconds: i * 55),
                  onPlay: (c) => c.repeat(),
                )
                .shimmer(
                  duration: 1400.ms,
                  color: AppColors.skeletonHighlight.withOpacity(0.3),
                ),
            childCount: 5,
          ),
        ),
      );

  // ── Empty / no results ────────────────────────────────────────────────────

  Widget _buildEmpty() => SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84, height: 84,
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.bookmark_border_rounded,
                    color: AppColors.textDisabled, size: 36),
              ),
              const SizedBox(height: 26),
              Text('Nothing saved yet',
                  style: _display(22,
                      weight: FontWeight.w700, letterSpacing: -0.4)),
              const SizedBox(height: 10),
              Text(
                'Search for comics and tap the\nbookmark icon to save them here.',
                textAlign: TextAlign.center,
                style: _ui(14,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w400,
                    height: 1.55),
              ),
            ],
          ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOutCubic),
        ),
      );

  Widget _buildNoResults() => SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.search_off_rounded,
                    color: AppColors.textDisabled, size: 32),
              ),
              const SizedBox(height: 24),
              Text('No results',
                  style: _display(20,
                      weight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 10),
              Text(
                'Try a different title or series name.',
                textAlign: TextAlign.center,
                style: _ui(13,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w400,
                    height: 1.55),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// WISHLIST CARD  — palette-tinted cover
// ══════════════════════════════════════════════════════════════════════════════

class _WishlistCard extends StatefulWidget {
  final Comic comic;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _WishlistCard({
    required this.comic,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_WishlistCard> createState() => _WishlistCardState();
}

class _WishlistCardState extends State<_WishlistCard> {
  Color _palette = Colors.black;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(_WishlistCard old) {
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
    final comic = widget.comic;

    return Pressable(
      onTap: widget.onTap,
      haptic: HapticStyle.light,
      scaleDown: 0.97,
      child: Container(
        height: 90,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold_(0.18)),
        ),
        child: Row(children: [
          // Gold accent stripe
          Container(
            width: 4,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.gold_(0.55),
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14)),
            ),
          ),

          // Cover with palette right-edge bleed
          SizedBox(
            width: 60,
            height: 90,
            child: Stack(fit: StackFit.expand, children: [
              comic.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: comic.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.surface2),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.surface2),
                    )
                  : Container(
                      color: AppColors.surface2,
                      child: const Center(
                        child: Icon(Icons.menu_book_rounded,
                            color: AppColors.textDisabled, size: 20),
                      ),
                    ),
              // Palette bleed into card body
              Positioned(
                top: 0, right: 0, bottom: 0,
                width: 32,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        _palette.withOpacity(0.88),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(width: 14),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  comic.seriesName,
                  style: _ui(11,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  comic.title.isNotEmpty
                      ? comic.title
                      : 'Issue #${comic.issueNumber ?? "?"}',
                  style: _ui(13,
                      color: AppColors.textPrimary,
                      weight: FontWeight.w700,
                      height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (comic.issueNumber != null ||
                    comic.publicationYear != null) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    if (comic.issueNumber != null)
                      _chip('#${comic.issueNumber}'),
                    if (comic.issueNumber != null &&
                        comic.publicationYear != null)
                      const SizedBox(width: 5),
                    if (comic.publicationYear != null)
                      _chip('${comic.publicationYear}'),
                  ]),
                ],
              ],
            ),
          ),

          // Remove bookmark button
          Pressable(
            onTap: widget.onRemove,
            haptic: HapticStyle.light,
            scaleDown: 0.85,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.bookmark_remove_rounded,
                  color: AppColors.gold_(0.5), size: 22),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: _ui(10,
                color: AppColors.textTertiary,
                weight: FontWeight.w600)),
      );
}

// ── Skeleton wishlist card ────────────────────────────────────────────────────

class _SkeletonWishlistCard extends StatelessWidget {
  const _SkeletonWishlistCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Stripe
        Container(
          width: 4,
          decoration: const BoxDecoration(
            color: AppColors.surface2,
            borderRadius:
                BorderRadius.horizontal(left: Radius.circular(14)),
          ),
        ),
        // Cover
        Container(width: 60, color: AppColors.skeletonBase),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  height: 10, width: 80,
                  decoration: BoxDecoration(
                      color: AppColors.skeletonBase,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 7),
              Container(
                  height: 13, width: 160,
                  decoration: BoxDecoration(
                      color: AppColors.skeletonBase,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(
                  height: 13, width: 120,
                  decoration: BoxDecoration(
                      color: AppColors.skeletonBase,
                      borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ]),
    );
  }
}