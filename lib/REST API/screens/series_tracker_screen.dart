// lib/REST API/screens/series_tracker_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/typography.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';
import '../../theme/app_colors.dart';
import '../../theme/services/comic_vine_service.dart';
import '../../theme/services/cover_palette_service.dart';
import '../../theme/services/database_service.dart';
import '../../theme/utils/haptics.dart';
import '../../../widgets/pressable.dart';
import 'series_run_screen.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _SeriesProgress {
  final String seriesName;
  final String? volumeId;
  final String? publisher;
  final String? coverImageUrl;
  int ownedCount;
  int wishlistCount;
  int? totalIssues;
  bool loadingTotal;

  _SeriesProgress({
    required this.seriesName,
    this.volumeId,
    this.publisher,
    this.coverImageUrl,
    required this.ownedCount,
    this.wishlistCount = 0,
    this.totalIssues,
    // ignore: unused_element_parameter
    this.loadingTotal = false,
  });

  double get completionPercent {
    if (totalIssues == null || totalIssues == 0) return 0;
    return (ownedCount / totalIssues!).clamp(0.0, 1.0);
  }

  int get rawGap {
    if (totalIssues == null) return 0;
    return (totalIssues! - ownedCount).clamp(0, totalIssues!);
  }

  int get missingCount {
    if (totalIssues == null) return 0;
    return (totalIssues! - ownedCount - wishlistCount).clamp(0, totalIssues!);
  }

  bool get isComplete => totalIssues != null && ownedCount >= totalIssues!;
  bool get hasVolumeData => volumeId != null;
}

enum _SortMode { missing, completion, name }

extension _SortModeLabel on _SortMode {
  String get label {
    switch (this) {
      case _SortMode.missing:    return 'Most Missing';
      case _SortMode.completion: return '% Complete';
      case _SortMode.name:       return 'A – Z';
    }
  }

  IconData get icon {
    switch (this) {
      case _SortMode.missing:    return Icons.playlist_remove_rounded;
      case _SortMode.completion: return Icons.bar_chart_rounded;
      case _SortMode.name:       return Icons.sort_by_alpha_rounded;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SeriesTrackerScreen extends StatefulWidget {
  const SeriesTrackerScreen({super.key});

  @override
  State<SeriesTrackerScreen> createState() => _SeriesTrackerScreenState();
}

class _SeriesTrackerScreenState extends State<SeriesTrackerScreen> {
  List<_SeriesProgress> _series = [];
  bool _loading = true;
  _SortMode _sort = _SortMode.missing;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  static final Map<String, int> _countCache = {};
  bool _fetchingTotals = false;
  bool _countsReady    = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (_searchCtrl.text != _query) {
        setState(() => _query = _searchCtrl.text);
      }
    });
    _loadFromDb();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadFromDb() async {
    setState(() => _loading = true);

    final comics   = await DatabaseService.instance.getAllComics();
    final wishlist = await DatabaseService.instance.getWishlist();

    final Map<String, _SeriesProgress> grouped = {};

    for (final comic in comics) {
      final key = comic.volumeId ??
          '__novolume__${comic.seriesName.trim().toLowerCase()}';

      if (grouped.containsKey(key)) {
        grouped[key]!.ownedCount++;
        if (grouped[key]!.coverImageUrl == null && comic.coverImageUrl != null) {
          grouped[key] = _SeriesProgress(
            seriesName:    grouped[key]!.seriesName,
            volumeId:      grouped[key]!.volumeId,
            publisher:     grouped[key]!.publisher,
            coverImageUrl: comic.coverImageUrl,
            ownedCount:    grouped[key]!.ownedCount,
            wishlistCount: grouped[key]!.wishlistCount,
            totalIssues:   grouped[key]!.totalIssues,
          );
        }
      } else {
        grouped[key] = _SeriesProgress(
          seriesName:    comic.seriesName,
          volumeId:      comic.volumeId,
          publisher:     comic.publisher,
          coverImageUrl: comic.coverImageUrl,
          ownedCount:    1,
          totalIssues:   comic.volumeId != null ? _countCache[comic.volumeId] : null,
        );
      }
    }

    for (final comic in wishlist) {
      final key = comic.volumeId ??
          '__novolume__${comic.seriesName.trim().toLowerCase()}';
      if (grouped.containsKey(key)) grouped[key]!.wishlistCount++;
    }

    final series = grouped.values.toList();
    _applySortInPlace(series);

    if (mounted) {
      setState(() {
        _series       = series;
        _loading      = false;
        _countsReady  = false;
      });
      _fetchMissingCounts();
    }
  }

  Future<void> _fetchMissingCounts() async {
    if (_fetchingTotals) return;
    _fetchingTotals = true;
    if (mounted) setState(() {});

    for (final s in List.of(_series)) {
      if (!mounted) break;
      if (s.volumeId == null) continue;

      if (_countCache.containsKey(s.volumeId!)) {
        s.totalIssues  = _countCache[s.volumeId!];
        s.loadingTotal = false;
        continue;
      }

      try {
        await Future.delayed(const Duration(milliseconds: 350));
        final count = await ComicVineService.instance.getVolumeIssueCount(s.volumeId!);
        _countCache[s.volumeId!] = count;
        s.totalIssues  = count;
        s.loadingTotal = false;
      } catch (_) {
        s.loadingTotal = false;
      }
    }

    _fetchingTotals = false;
    if (mounted) {
      setState(() {
        _countsReady = true;
        _applySortInPlace(_series);
      });
    }
  }

  // ── Sorting ───────────────────────────────────────────────────────────────

  void _applySortInPlace(List<_SeriesProgress> list) {
    switch (_sort) {
      case _SortMode.name:
        list.sort((a, b) =>
            a.seriesName.toLowerCase().compareTo(b.seriesName.toLowerCase()));

      case _SortMode.completion:
        list.sort((a, b) {
          if (a.isComplete != b.isComplete) return a.isComplete ? 1 : -1;
          final aKnown = a.totalIssues != null;
          final bKnown = b.totalIssues != null;
          if (aKnown != bKnown) return aKnown ? -1 : 1;
          final diff = b.completionPercent.compareTo(a.completionPercent);
          if (diff != 0) return diff;
          return a.seriesName.toLowerCase().compareTo(b.seriesName.toLowerCase());
        });

      case _SortMode.missing:
        list.sort((a, b) {
          int tier(_SeriesProgress s) {
            if (s.isComplete) return 2;
            if (s.totalIssues == null) return 1;
            return 0;
          }

          final ta = tier(a), tb = tier(b);
          if (ta != tb) return ta.compareTo(tb);

          if (ta == 0) {
            final diff = b.rawGap.compareTo(a.rawGap);
            if (diff != 0) return diff;
          } else {
            final diff = b.ownedCount.compareTo(a.ownedCount);
            if (diff != 0) return diff;
          }

          return a.seriesName.toLowerCase().compareTo(b.seriesName.toLowerCase());
        });
    }
  }

  void _changeSort(_SortMode mode) {
    if (_sort == mode) return;
    AppHaptics.select();
    setState(() {
      _sort = mode;
      if (_countsReady || mode == _SortMode.name) _applySortInPlace(_series);
    });
  }

  // ── Filter sheet ──────────────────────────────────────────────────────────

  void _openSortSheet() {
    AppHaptics.select();
    var tempSort = _sort;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text('Sort By',
                    style: tDisplay(18,
                        weight: FontWeight.w700, letterSpacing: -0.3)),
              ),

              Divider(
                  height: 1,
                  color: AppColors.border.withOpacity(0.5),
                  indent: 20,
                  endIndent: 20),

              const SizedBox(height: 12),

              ...(_SortMode.values.map((mode) {
                final active = tempSort == mode;
                return Pressable(
                  onTap: () {
                    AppHaptics.light();
                    setSheetState(() => tempSort = mode);
                  },
                  haptic: HapticStyle.none,
                  scaleDown: 0.98,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.surface3
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? AppColors.borderFocus
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(children: [
                      Icon(mode.icon,
                          size: 18,
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textSecondary),
                      const SizedBox(width: 14),
                      Text(mode.label,
                          style: tUi(15,
                              color: active
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              weight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                      if (active) ...[
                        const Spacer(),
                        const Icon(Icons.check_rounded,
                            color: AppColors.textPrimary, size: 16),
                      ],
                    ]),
                  ),
                );
              })),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Pressable(
                  onTap: () {
                    AppHaptics.medium();
                    _changeSort(tempSort);
                    Navigator.pop(ctx);
                  },
                  haptic: HapticStyle.none,
                  scaleDown: 0.97,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text('Apply',
                          style: tUi(15,
                              color: AppColors.bg,
                              weight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openSeries(_SeriesProgress s) {
    if (s.volumeId == null) return;
    AppHaptics.light();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => SeriesRunScreen(
          seriesName: s.seriesName,
          volumeId:   s.volumeId!,
          onChanged:  _loadFromDb,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  // ── Derived ───────────────────────────────────────────────────────────────

  List<_SeriesProgress> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _series;
    return _series
        .where((s) =>
            s.seriesName.toLowerCase().contains(q) ||
            (s.publisher?.toLowerCase().contains(q) ?? false))
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
            _buildLoading()
          else if (_series.isEmpty)
            _buildEmpty()
          else ...[
            _buildSearchBar(),
            if (filtered.isEmpty)
              _buildNoResults()
            else
              _buildList(filtered),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
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
                  color: AppColors.textSecondary, size: 16,
                  semanticLabel: 'Back'),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MY SERIES',
                style: tUi(10,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const SizedBox(height: 2),
            Text('Collection Tracker',
                style: tDisplay(17,
                    weight: FontWeight.w700, letterSpacing: -0.4)),
          ],
        ),
      );

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(children: [
            // Search field
            Expanded(
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
                      style: tUi(14, weight: FontWeight.w400),
                      cursorColor: AppColors.textSecondary,
                      cursorWidth: 1.5,
                      decoration: InputDecoration(
                        hintText: 'Search series…',
                        hintStyle: tUi(14,
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

            const SizedBox(width: 10),

            // Sort button
            Pressable(
              onTap: _openSortSheet,
              haptic: HapticStyle.none,
              scaleDown: 0.88,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _sort != _SortMode.missing
                          ? AppColors.surface3
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _sort != _SortMode.missing
                            ? AppColors.borderFocus
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(Icons.swap_vert_rounded,
                        color: _sort != _SortMode.missing
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        size: 18),
                  ),
                  // Fetching indicator dot
                  if (_fetchingTotals)
                    Positioned(
                      top: -3, right: -3,
                      child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.bg, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
      );

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList(List<_SeriesProgress> filtered) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final s = filtered[i];
              return _SeriesCard(
                series: s,
                onTap:  s.hasVolumeData ? () => _openSeries(s) : null,
              )
                  .animate(
                      delay: Duration(
                          milliseconds: (i * 40).clamp(0, 400)))
                  .fadeIn(duration: 280.ms)
                  .slideY(
                      begin: 0.04,
                      end: 0,
                      curve: Curves.easeOutCubic);
            },
            childCount: filtered.length,
          ),
        ),
      );

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoading() => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => const _SkeletonSeriesCard()
                .animate(
                  delay: Duration(milliseconds: i * 55),
                  onPlay: (c) => c.repeat(),
                )
                .shimmer(
                  duration: 1400.ms,
                  color: AppColors.skeletonHighlight.withOpacity(0.3),
                ),
            childCount: 6,
          ),
        ),
      );

  // ── Empty / no results ────────────────────────────────────────────────────

  Widget _buildEmpty() => SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.auto_stories_rounded,
                      color: AppColors.textDisabled, size: 32),
                ),
                const SizedBox(height: 24),
                Text('No Series Yet',
                    style: tDisplay(20,
                        weight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 10),
                Text(
                  'Add comics to your library\nto track series completion.',
                  textAlign: TextAlign.center,
                  style: tUi(13,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w400,
                      height: 1.55),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms),
          ),
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
                  style: tDisplay(20,
                      weight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 10),
              Text(
                'Try a different series name\nor publisher.',
                textAlign: TextAlign.center,
                style: tUi(13,
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
// SERIES CARD  — palette-tinted cover
// ══════════════════════════════════════════════════════════════════════════════

class _SeriesCard extends StatefulWidget {
  final _SeriesProgress series;
  final VoidCallback? onTap;

  const _SeriesCard({required this.series, this.onTap});

  @override
  State<_SeriesCard> createState() => _SeriesCardState();
}

class _SeriesCardState extends State<_SeriesCard> {
  Color _palette = Colors.black;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(_SeriesCard old) {
    super.didUpdateWidget(old);
    if (old.series.coverImageUrl != widget.series.coverImageUrl) {
      _loadPalette();
    }
  }

  Future<void> _loadPalette() async {
    final c = await CoverPaletteService.instance
        .getColor(widget.series.coverImageUrl);
    if (mounted) setState(() => _palette = c);
  }

  @override
  Widget build(BuildContext context) {
    final s   = widget.series;
    final pct = s.completionPercent;

    final barColor = s.isComplete
        ? AppColors.greenOwned
        : pct >= 0.66
            ? AppColors.gold
            : _palette == Colors.black
                ? AppColors.textSecondary.withOpacity(0.5)
                : _palette;

    return Pressable(
      onTap: widget.onTap,
      haptic: HapticStyle.light,
      scaleDown: 0.97,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: s.isComplete
                ? AppColors.green_(0.22)
                : AppColors.border,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(children: [
            Row(children: [
              // ── Cover with palette bleed ─────────────────────────────
              SizedBox(
                width: 76,
                height: 108,
                child: Stack(fit: StackFit.expand, children: [
                  s.coverImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: s.coverImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.surface2),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.surface2),
                        )
                      : Container(
                          color: AppColors.surface2,
                          child: const Center(
                            child: Icon(Icons.auto_stories_rounded,
                                color: AppColors.textDisabled, size: 22),
                          ),
                        ),
                  // Palette right-edge bleed into card
                  Positioned(
                    top: 0, right: 0, bottom: 0,
                    width: 44,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            _palette.withOpacity(0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Complete badge
                  if (s.isComplete)
                    Positioned(
                      top: 7, left: 7,
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: AppColors.greenOwned, size: 11),
                      ),
                    ),
                ]),
              ),

              // ── Info ─────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.seriesName,
                          style: tUi(14,
                              color: AppColors.textPrimary,
                              weight: FontWeight.w700,
                              height: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (s.publisher != null) ...[
                        const SizedBox(height: 3),
                        Text(s.publisher!,
                            style: tUi(11,
                                color: AppColors.textTertiary,
                                weight: FontWeight.w400)),
                      ],
                      const SizedBox(height: 10),
                      _buildChips(s),
                    ],
                  ),
                ),
              ),

              // ── Right badge ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _buildRightBadge(s, pct),
              ),
            ]),

            // ── Progress bar ─────────────────────────────────────────────
            if (s.totalIssues != null)
              _AnimatedProgressBar(value: pct, color: barColor)
            else if (s.hasVolumeData)
              // Skeleton bar while count is loading
              Container(
                height: 4,
                color: AppColors.surface2,
              )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(
                    duration: 1400.ms,
                    color: AppColors.skeletonHighlight.withOpacity(0.4),
                  ),
          ]),
        ),
      ),
    );
  }

  Widget _buildChips(_SeriesProgress s) => Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _chip('${s.ownedCount} owned', AppColors.greenOwned),
          if (s.wishlistCount > 0)
            _chip('${s.wishlistCount} wanted', AppColors.gold),
          if (s.totalIssues != null && s.missingCount > 0)
            _chip('${s.missingCount} missing', AppColors.textTertiary),
        ],
      );

  Widget _buildRightBadge(_SeriesProgress s, double pct) {
    if (s.isComplete) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.green_(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.green_(0.25)),
        ),
        child: Text('✓ Done',
            style: tUi(10,
                color: AppColors.greenOwned,
                weight: FontWeight.w700)),
      );
    }
    if (s.totalIssues != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(pct * 100).round()}%',
            style: tUi(16,
                color: AppColors.textPrimary,
                weight: FontWeight.w700),
          ),
          Text(
            '${s.ownedCount}/${s.totalIssues}',
            style: tUi(10,
                color: AppColors.textDisabled,
                weight: FontWeight.w400),
          ),
        ],
      );
    }
    return Icon(
      s.hasVolumeData
          ? Icons.chevron_right_rounded
          : Icons.help_outline_rounded,
      color: AppColors.textDisabled,
      size: 16,
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: tUi(10, color: color, weight: FontWeight.w600)),
      );
}

// ── Animated progress bar ─────────────────────────────────────────────────────

class _AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const _AnimatedProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => LayoutBuilder(
        builder: (_, constraints) => Stack(children: [
          Container(height: 4, color: AppColors.border.withOpacity(0.35)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            height: 4,
            width: constraints.maxWidth * v,
            color: color,
          ),
        ]),
      ),
    );
  }
}

// ── Skeleton card ─────────────────────────────────────────────────────────────

class _SkeletonSeriesCard extends StatelessWidget {
  const _SkeletonSeriesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 112,
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
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 14, width: 140,
                    decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(
                    height: 10, width: 80,
                    decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(4))),
                const Spacer(),
                Row(children: [
                  Container(
                      height: 22, width: 60,
                      decoration: BoxDecoration(
                          color: AppColors.skeletonBase,
                          borderRadius: BorderRadius.circular(5))),
                  const SizedBox(width: 6),
                  Container(
                      height: 22, width: 50,
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