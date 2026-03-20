// lib/REST API/screens/library_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/typography.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';
import '../../../widgets/comic_card.dart';
import '../../../widgets/pressable.dart';
import '../../../widgets/skeleton_box.dart';

import '../../theme/app_colors.dart';
import '../../theme/models/comic.dart';
import '../../theme/services/database_service.dart';
import '../../theme/utils/haptics.dart';
import 'comic_detail_screen.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum _SortMode { dateAdded, seriesAZ, rating, year }

extension _SortModeLabel on _SortMode {
  String get label {
    switch (this) {
      case _SortMode.dateAdded: return 'Date Added';
      case _SortMode.seriesAZ:  return 'Series A–Z';
      case _SortMode.rating:    return 'Top Rated';
      case _SortMode.year:      return 'Year';
    }
  }

  IconData get icon {
    switch (this) {
      case _SortMode.dateAdded: return Icons.schedule_rounded;
      case _SortMode.seriesAZ:  return Icons.auto_stories_rounded;
      case _SortMode.rating:    return Icons.star_rounded;
      case _SortMode.year:      return Icons.calendar_today_rounded;
    }
  }
}

enum _FilterMode { all, read, unread, reading }

extension _FilterModeLabel on _FilterMode {
  String get label {
    switch (this) {
      case _FilterMode.all:     return 'All';
      case _FilterMode.read:    return 'Read';
      case _FilterMode.unread:  return 'Unread';
      case _FilterMode.reading: return 'Reading';
    }
  }
}

enum _ViewMode { grid, list }

// ── Screen ────────────────────────────────────────────────────────────────────

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  List<Comic> _all = [];
  bool _loading = true;

  _SortMode   _sort   = _SortMode.dateAdded;
  _FilterMode _filter = _FilterMode.all;
  _ViewMode   _view   = _ViewMode.grid;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // Shimmer — single controller shared across all skeleton cards so only one
  // animation drives the repaint instead of N independent ones.
  late final AnimationController _shimmerCtrl;

  // Memoised derived lists — recomputed only when _all, _query, _sort or
  // _filter actually change, not on every build() call.
  List<Comic>? _cachedFiltered;
  Map<String, List<Comic>>? _cachedGrouped;

  void _invalidateCache() {
    _cachedFiltered = null;
    _cachedGrouped  = null;
  }

  // Returns true when anything deviates from the defaults
  bool get _hasActiveFilters =>
      _sort != _SortMode.dateAdded || _filter != _FilterMode.all;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _searchCtrl.addListener(() {
      if (_searchCtrl.text != _query) {
        setState(() { _query = _searchCtrl.text; _invalidateCache(); });
      }
    });
    _load();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final comics = await DatabaseService.instance.getAllComics();
    if (mounted) setState(() { _all = comics; _loading = false; _invalidateCache(); });
  }

  /// Refreshes the data without flipping the loading skeleton, so the UI
  /// stays visible while the list updates after an edit.
  Future<void> _silentRefresh() async {
    final comics = await DatabaseService.instance.getAllComics();
    if (mounted) setState(() { _all = comics; _invalidateCache(); });
  }

  // ── Derived lists (memoised) ──────────────────────────────────────────────
  //
  // Both getters write through to a cache that is invalidated by
  // _invalidateCache() whenever _all, _query, _sort, or _filter changes.
  // This means the O(n log n) sort and O(n²) grouping only run once per
  // actual state change, not on every build() call.

  List<Comic> get _filtered {
    _cachedFiltered ??= _computeFiltered();
    return _cachedFiltered!;
  }

  List<Comic> _computeFiltered() {
    var list = List.of(_all);

    if (_filter == _FilterMode.read)    list = list.where((c) => c.isRead).toList();
    if (_filter == _FilterMode.unread)  list = list.where((c) => !c.isRead).toList();
    if (_filter == _FilterMode.reading) list = list.where((c) => c.isReading).toList();

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) =>
        c.seriesName.toLowerCase().contains(q) ||
        c.title.toLowerCase().contains(q) ||
        (c.issueNumber?.toLowerCase().contains(q) ?? false) ||
        (c.writers?.toLowerCase().contains(q) ?? false) ||
        (c.publisher?.toLowerCase().contains(q) ?? false),
      ).toList();
    }

    switch (_sort) {
      case _SortMode.dateAdded:
        list.sort((a, b) => b.addedDate.compareTo(a.addedDate));
      case _SortMode.seriesAZ:
        list.sort((a, b) {
          final s = a.seriesName.compareTo(b.seriesName);
          if (s != 0) return s;
          return _issueCompare(a.issueNumber, b.issueNumber);
        });
      case _SortMode.rating:
        list.sort((a, b) => b.starRating.compareTo(a.starRating));
      case _SortMode.year:
        list.sort((a, b) =>
            (b.publicationYear ?? 0).compareTo(a.publicationYear ?? 0));
    }

    return list;
  }

  int _issueCompare(String? a, String? b) {
    final na = double.tryParse(a ?? '') ?? 0;
    final nb = double.tryParse(b ?? '') ?? 0;
    return na.compareTo(nb);
  }

  Map<String, List<Comic>> get _groupedBySeries {
    _cachedGrouped ??= _computeGroupedBySeries();
    return _cachedGrouped!;
  }

  Map<String, List<Comic>> _computeGroupedBySeries() {
    // Reuse the already-cached filtered list so we don't redo the sort.
    final filtered = _filtered;
    final map = <String, List<Comic>>{};
    for (final comic in filtered) {
      map.putIfAbsent(comic.seriesName, () => []).add(comic);
    }
    for (final list in map.values) {
      list.sort((a, b) => _issueCompare(a.issueNumber, b.issueNumber));
    }
    final keys = map.keys.toList();
    if (_sort == _SortMode.seriesAZ) {
      keys.sort();
    } else if (_sort == _SortMode.rating) {
      keys.sort((a, b) {
        final maxA = map[a]!.map((c) => c.starRating).reduce((x, y) => x > y ? x : y);
        final maxB = map[b]!.map((c) => c.starRating).reduce((x, y) => x > y ? x : y);
        return maxB.compareTo(maxA);
      });
    } else {
      keys.sort((a, b) {
        final latestA = map[a]!.map((c) => c.addedDate).reduce((x, y) => x.isAfter(y) ? x : y);
        final latestB = map[b]!.map((c) => c.addedDate).reduce((x, y) => x.isAfter(y) ? x : y);
        return latestB.compareTo(latestA);
      });
    }
    return { for (final k in keys) k: map[k]! };
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openDetail(Comic comic) {
    AppHaptics.light();
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => ComicDetailScreen(
          comic: comic, onUpdated: _silentRefresh, mode: ComicDetailMode.owned),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 260),
    ));
  }

  // ── Filter sheet ──────────────────────────────────────────────────────────

  void _openFilterSheet() {
    AppHaptics.select();

    // Capture current state so the sheet can work on a local copy
    // and only apply on "Done" — feel free to change to live-apply if preferred.
    var tempSort   = _sort;
    var tempFilter = _filter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            // SafeArea padding for home bar
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Handle ────────────────────────────────────────────────
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Header row ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                  child: Row(
                    children: [
                      Text('Sort & Filter',
                          style: tDisplay(18,
                              weight: FontWeight.w700, letterSpacing: -0.3)),
                      const Spacer(),
                      // Reset button — only visible when something is non-default
                      if (tempSort != _SortMode.dateAdded ||
                          tempFilter != _FilterMode.all)
                        Pressable(
                          onTap: () {
                            AppHaptics.light();
                            setSheetState(() {
                              tempSort   = _SortMode.dateAdded;
                              tempFilter = _FilterMode.all;
                            });
                          },
                          haptic: HapticStyle.none,
                          scaleDown: 0.9,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text('Reset',
                                style: tUi(12,
                                    color: AppColors.textSecondary,
                                    weight: FontWeight.w500)),
                          ),
                        ),
                    ],
                  ),
                ),

                Divider(
                    height: 1,
                    color: AppColors.border.withOpacity(0.5),
                    indent: 20,
                    endIndent: 20),

                const SizedBox(height: 20),

                // ── Sort section ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('SORT BY',
                      style: tUi(10,
                          color: AppColors.textTertiary,
                          weight: FontWeight.w700,
                          letterSpacing: 1.4)),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _SortMode.values.map((s) {
                      final active = tempSort == s;
                      return Pressable(
                        onTap: () {
                          AppHaptics.light();
                          setSheetState(() => tempSort = s);
                        },
                        haptic: HapticStyle.none,
                        scaleDown: 0.94,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.surface3
                                : AppColors.surface1,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active
                                  ? AppColors.borderFocus
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(s.icon,
                                size: 13,
                                color: active
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary),
                            const SizedBox(width: 6),
                            Text(s.label,
                                style: tUi(13,
                                    color: active
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    weight: active
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 22),

                // ── Filter section ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('SHOW',
                      style: tUi(10,
                          color: AppColors.textTertiary,
                          weight: FontWeight.w700,
                          letterSpacing: 1.4)),
                ),
                const SizedBox(height: 10),

                // Full-width segmented control feel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: _FilterMode.values.map((f) {
                        final active = tempFilter == f;
                        final isFirst = f == _FilterMode.values.first;
                        final isLast  = f == _FilterMode.values.last;
                        return Expanded(
                          child: Pressable(
                            onTap: () {
                              AppHaptics.light();
                              setSheetState(() => tempFilter = f);
                            },
                            haptic: HapticStyle.none,
                            scaleDown: 0.96,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.surface3
                                    : Colors.transparent,
                                borderRadius: BorderRadius.horizontal(
                                  left:  isFirst
                                      ? const Radius.circular(10)
                                      : Radius.zero,
                                  right: isLast
                                      ? const Radius.circular(10)
                                      : Radius.zero,
                                ),
                                border: active
                                    ? Border.all(color: AppColors.borderFocus)
                                    : null,
                              ),
                              child: Center(
                                child: Text(f.label,
                                    style: tUi(13,
                                        color: active
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                        weight: active
                                            ? FontWeight.w600
                                            : FontWeight.w400)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Done button ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Pressable(
                    onTap: () {
                      AppHaptics.medium();
                      setState(() {
                        _sort   = tempSort;
                        _filter = tempFilter;
                        _invalidateCache();
                      });
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
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final comics = _filtered;
    final read   = _all.where((c) => c.isRead).length;
    final total  = _all.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.textPrimary,
        backgroundColor: AppColors.surface2,
        strokeWidth: 2,
        displacement: 60,
        child: CustomScrollView(
          physics: const BottomBouncingScrollPhysics(),
          slivers: [
            _buildAppBar(total: total, read: read),
            _buildSearchBar(),
            if (_loading)
              _buildShimmer()
            else if (comics.isEmpty)
              _buildEmpty()
            else if (_view == _ViewMode.grid)
              _buildGrid(comics)
            else
              _buildList(),
            const SliverToBoxAdapter(child: SizedBox(height: 64)),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar({required int total, required int read}) =>
      SliverAppBar(
        pinned: true,
        backgroundColor: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1,
              color: AppColors.border.withOpacity(0.5)),
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
            Text('MY COLLECTION',
                style: tUi(10,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Library',
                    style: tDisplay(17,
                        weight: FontWeight.w700, letterSpacing: -0.4)),
                if (total > 0) ...[
                  const SizedBox(width: 10),
                  Text(
                    '$total comics · $read read',
                    style: tUi(11,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w400),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          // View toggle — grid ↔ list
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Pressable(
              onTap: () {
                AppHaptics.select();
                setState(() => _view = _view == _ViewMode.grid
                    ? _ViewMode.list
                    : _ViewMode.grid);
              },
              haptic: HapticStyle.none,
              scaleDown: 0.88,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  _view == _ViewMode.grid
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  color: AppColors.textSecondary,
                  size: 17,
                  semanticLabel: _view == _ViewMode.grid
                      ? 'Switch to list view'
                      : 'Switch to grid view',
                ),
              ),
            ),
          ),
        ],
      );

  // ── Search bar — single row with filter button ────────────────────────────

  Widget _buildSearchBar() => SliverToBoxAdapter(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                        hintText: 'Search your library…',
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

            // Filter / sort button with active-state dot
            Pressable(
              onTap: _openFilterSheet,
              haptic: HapticStyle.none,
              scaleDown: 0.88,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _hasActiveFilters
                          ? AppColors.surface3
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasActiveFilters
                            ? AppColors.borderFocus
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: _hasActiveFilters
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      size: 18,
                      semanticLabel: 'Sort and filter',
                    ),
                  ),
                  // Active-state indicator dot
                  if (_hasActiveFilters)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
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

        // Active filter summary pill — subtle, single-line reminder
        if (_hasActiveFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.tune_rounded,
                      size: 11, color: AppColors.textTertiary),
                  const SizedBox(width: 5),
                  Text(
                    [
                      if (_sort != _SortMode.dateAdded) _sort.label,
                      if (_filter != _FilterMode.all) _filter.label,
                    ].join(' · '),
                    style: tUi(11,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Pressable(
                    onTap: () {
                      AppHaptics.light();
                      setState(() {
                        _sort   = _SortMode.dateAdded;
                        _filter = _FilterMode.all;
                        _invalidateCache();
                      });
                    },
                    haptic: HapticStyle.none,
                    scaleDown: 0.85,
                    child: const Icon(Icons.close_rounded,
                        size: 12, color: AppColors.textTertiary),
                  ),
                ]),
              ),
            ]),
          ),

        Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
      ],
    ),
  );

  // ── Grid view ─────────────────────────────────────────────────────────────

  Widget _buildGrid(List<Comic> comics) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.67,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => ComicCard(
          key: ValueKey(comics[i].comicVineId),
          comic: comics[i],
          onTap: () => _openDetail(comics[i]),
        )
            .animate(delay: Duration(milliseconds: (i * 20).clamp(0, 300)))
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
        childCount: comics.length,
      ),
    ),
  );

  // ── List view — series grouped ────────────────────────────────────────────

  Widget _buildList() {
    final grouped = _groupedBySeries;
    final entries = grouped.entries.toList();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final series = entries[i].key;
            final comics = entries[i].value;
            return _SeriesGroup(
              seriesName: series,
              comics: comics,
              onTap: _openDetail,
            )
                .animate(
                    delay: Duration(milliseconds: (i * 40).clamp(0, 400)))
                .fadeIn(duration: 280.ms)
                .slideY(
                    begin: 0.03,
                    end: 0,
                    curve: Curves.easeOutCubic);
          },
          childCount: entries.length,
        ),
      ),
    );
  }

  // ── Loading shimmer ───────────────────────────────────────────────────────

  Widget _buildShimmer() => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.67,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        // All skeletons share one AnimationController so only a single
        // animation drives repaints instead of 9 independent timers.
        (_, __) => const SkeletonBox.cover()
            .animate(controller: _shimmerCtrl)
            .shimmer(
              color: AppColors.skeletonHighlight.withOpacity(0.3),
            ),
        childCount: 9,
      ),
    ),
  );

  // ── Empty state ───────────────────────────────────────────────────────────

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
            child: const Icon(Icons.library_books_rounded,
                color: AppColors.textDisabled, size: 36),
          ),
          const SizedBox(height: 26),
          Text(
            _query.isNotEmpty || _filter != _FilterMode.all
                ? 'No results'
                : 'Your library is empty',
            style: tDisplay(22,
                weight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(height: 10),
          Text(
            _query.isNotEmpty || _filter != _FilterMode.all
                ? 'Try adjusting your search\nor filter.'
                : 'Search for comics and add them\nto start building your collection.',
            textAlign: TextAlign.center,
            style: tUi(14,
                color: AppColors.textTertiary,
                weight: FontWeight.w400,
                height: 1.55),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms, curve: Curves.easeOutCubic),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SERIES GROUP  (list view)
// ══════════════════════════════════════════════════════════════════════════════

class _SeriesGroup extends StatefulWidget {
  final String seriesName;
  final List<Comic> comics;
  final void Function(Comic) onTap;

  const _SeriesGroup({
    required this.seriesName,
    required this.comics,
    required this.onTap,
  });

  @override
  State<_SeriesGroup> createState() => _SeriesGroupState();
}

class _SeriesGroupState extends State<_SeriesGroup> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.comics.length == 1;
  }

  @override
  Widget build(BuildContext context) {
    final comics   = widget.comics;
    final owned    = comics.where((c) => c.isRead).length;
    final hasRated = comics.any((c) => c.starRating > 0);
    final maxRating = hasRated
        ? comics.map((c) => c.starRating).reduce((a, b) => a > b ? a : b)
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Pressable(
            onTap: comics.length > 1
                ? () {
                    AppHaptics.select();
                    setState(() => _expanded = !_expanded);
                  }
                : () => widget.onTap(comics.first),
            haptic: HapticStyle.none,
            scaleDown: 0.98,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: _CoverStack(comics: comics.take(3).toList()),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.seriesName,
                        style: tUi(14,
                            color: AppColors.textPrimary,
                            weight: FontWeight.w700,
                            height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(children: [
                        _metaChip('${comics.length} issue${comics.length == 1 ? '' : 's'}'),
                        const SizedBox(width: 6),
                        if (owned > 0)
                          _metaChip('$owned/${comics.length} read',
                              color: AppColors.greenOwned),
                        if (hasRated) ...[
                          const SizedBox(width: 6),
                          _metaChip('★ $maxRating',
                              color: AppColors.gold),
                        ],
                      ]),
                    ],
                  ),
                ),
                if (comics.length > 1)
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary, size: 20),
                  ),
              ]),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(
                    height: 1,
                    color: AppColors.border.withOpacity(0.5),
                    indent: 14,
                    endIndent: 14),
                ...comics.asMap().entries.map((e) {
                  final i     = e.key;
                  final comic = e.value;
                  return _IssueRow(
                    comic: comic,
                    isLast: i == comics.length - 1,
                    onTap: () => widget.onTap(comic),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String label, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      label,
      style: tUi(10,
          color: color ?? AppColors.textTertiary,
          weight: FontWeight.w600),
    ),
  );
}

// ── Cover stack ───────────────────────────────────────────────────────────────

class _CoverStack extends StatelessWidget {
  final List<Comic> comics;
  const _CoverStack({required this.comics});

  @override
  Widget build(BuildContext context) {
    final count = comics.length.clamp(1, 3);
    return Stack(
      children: List.generate(count, (i) {
        final offset = (count - 1 - i) * 5.0;
        return Positioned(
          left: offset,
          top: offset * 0.3,
          right: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: comics[i].coverImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: comics[i].coverImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.surface2),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppColors.surface2),
                  )
                : Container(
                    color: AppColors.surface2,
                    child: const Center(
                      child: Icon(Icons.menu_book_rounded,
                          color: AppColors.textDisabled, size: 14),
                    ),
                  ),
          ),
        );
      }).reversed.toList(),
    );
  }
}

// ── Issue row ─────────────────────────────────────────────────────────────────

class _IssueRow extends StatelessWidget {
  final Comic comic;
  final bool isLast;
  final VoidCallback onTap;

  const _IssueRow({
    required this.comic,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: HapticStyle.light,
      scaleDown: 0.98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.border.withOpacity(0.4),
                    width: 1,
                  ),
                ),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 36,
              height: 54,
              child: comic.coverImageUrl != null
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
                            color: AppColors.textDisabled, size: 14),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (comic.issueNumber != null)
                  Text(
                    'Issue #${comic.issueNumber}',
                    style: tUi(10,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w600,
                        letterSpacing: 0.3),
                  ),
                const SizedBox(height: 2),
                Text(
                  comic.title.isNotEmpty ? comic.title : comic.seriesName,
                  style: tUi(13,
                      color: AppColors.textPrimary,
                      weight: FontWeight.w600,
                      height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (comic.publicationYear != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${comic.publicationYear}',
                    style: tUi(11,
                        color: AppColors.textDisabled,
                        weight: FontWeight.w400),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (comic.isRead)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.greenOwnedDim,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: AppColors.green_(0.2)),
                  ),
                  child: Text('Read',
                      style: tUi(10,
                          color: AppColors.greenOwned,
                          weight: FontWeight.w600)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('Unread',
                      style: tUi(10,
                          color: AppColors.textDisabled,
                          weight: FontWeight.w500)),
                ),
              if (comic.starRating > 0) ...[
                const SizedBox(height: 5),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.gold, size: 11),
                  const SizedBox(width: 3),
                  Text('${comic.starRating}',
                      style: tUi(11,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w600)),
                ]),
              ],
            ],
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textDisabled, size: 16),
        ]),
      ),
    );
  }
}