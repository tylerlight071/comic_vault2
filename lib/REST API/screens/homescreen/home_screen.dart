// lib/REST API/screens/homescreen/home_screen.dart
//
// Entry point for the home screen. All imports live here; the part files
// inherit this scope automatically — no extra imports needed in them.

// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../utils/bottom_bouncing_scroll_physics.dart';
import '../../../../widgets/pressable.dart';
import '../../../../widgets/skeleton_box.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/models/comic.dart';
import '../../../theme/services/cover_palette_service.dart';
import '../../../theme/services/database_service.dart';
import '../../../theme/models/home_layout.dart';
import '../../../theme/models/shelf_config.dart';
import '../../../theme/services/comic_vine_service.dart';
import '../../../theme/utils/haptics.dart';
import 'home_typography.dart';
import '../scanner_screen.dart';
import '../search_results/search_results_screen.dart';
import '../comic_detail/comic_detail_screen.dart';
import '../wishlist_screen.dart';
import '../settings/settings_screen.dart';
import '../series_tracker_screen.dart';
import '../library_screen.dart';
import '../series_run_screen.dart';
import '../stats_screen.dart';
import '../reading_log_screen.dart';

part 'home_screen_drawer.dart';
part 'home_screen_header.dart';
part 'home_screen_components.dart';
part 'home_screen_layouts.dart';
part 'home_screen_skeletons.dart';
part 'home_screen_empty.dart';

// ── Home screen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Comic> _all = [];
  bool _loading = true;
  HomeLayout  _layout  = HomeLayout.featured;
  ShelfConfig _shelves = const ShelfConfig();

  // Cached shelf lists — computed once after each load, not on every build().
  int         _wishlistCount    = 0;
  List<Comic> _currentlyReading = [];
  List<Comic> _recentlyAdded    = [];
  List<Comic> _continueReading  = [];
  List<Comic> _topRated         = [];
  Comic?      _featuredComic;
  String      _spotlightLabel = 'SPOTLIGHT';
  // How many comics to show in the Recently Added shelf. Enough to give a
  // meaningful snapshot without the row feeling endless.
  static const int _recentlyAddedLimit = 6;

  @override
  void initState() {
    super.initState();
    _loadLayout();
    _loadShelfConfig();
    _load();
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('home_layout') ?? 0;
    if (mounted) setState(() => _layout = HomeLayout.values[idx.clamp(0, 2)]);
  }

  Future<void> _loadShelfConfig() async {
    final config = await ShelfConfig.load();
    if (mounted) setState(() => _shelves = config);
  }

  Future<void> _setLayout(HomeLayout l) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('home_layout', l.index);
    if (mounted) setState(() => _layout = l);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      DatabaseService.instance.getAllComics(),
      DatabaseService.instance.getWishlistCount(),
    ]);
    final comics = results[0] as List<Comic>;
    final wCount = results[1] as int;
    if (mounted) {
      setState(() {
        _all = comics;
        _wishlistCount = wCount;
        _loading = false;
        _updateShelves(comics);
      });
      _warmPalette(comics);
    }
  }

  /// Refreshes data without showing the loading skeleton — used after edits or
  /// returning from sub-screens so the home screen stays visible while updating.
  Future<void> _silentRefresh() async {
    final results = await Future.wait([
      DatabaseService.instance.getAllComics(),
      DatabaseService.instance.getWishlistCount(),
    ]);
    final comics = results[0] as List<Comic>;
    final wCount = results[1] as int;
    if (mounted) {
      setState(() {
        _all = comics;
        _wishlistCount = wCount;
        _updateShelves(comics);
      });
      _warmPalette(comics);
    }
  }

  /// Pre-warms the palette cache for the first N covers so shelf cards render
  /// their tinted gradient on the first frame instead of flashing from black.

void _warmPalette(List<Comic> comics) {
  const warmCount = 12;
  final urls = comics
      .where((c) => c.coverImageUrl != null)
      .take(warmCount)
      .map((c) => c.coverImageUrl!)
      .toList();
  // Fire all requests concurrently — CoverPaletteService deduplicates
  // in-flight requests so there is no risk of redundant network calls.
  Future.wait(urls.map(CoverPaletteService.instance.getColor));
}

  // ── Shelf data helpers ────────────────────────────────────────────────────
  //
  // These compute methods are called once inside _load()/_silentRefresh() and
  // their results stored in fields. Getters that ran on every build() caused
  // O(n log n) sorts to repeat for every setState (layout toggle, scroll, etc).

  List<Comic> _computeRecentlyAdded(List<Comic> comics) {
    final sorted = List.of(comics)
      ..sort((a, b) => b.addedDate.compareTo(a.addedDate));
    return sorted.take(_recentlyAddedLimit).toList();
  }

  List<Comic> _computeCurrentlyReading(List<Comic> comics) =>
      (comics.where((c) => c.isReading).toList()
        ..sort((a, b) => b.addedDate.compareTo(a.addedDate)));

  List<Comic> _computeContinueReading(List<Comic> comics) =>
      (comics.where((c) => !c.isRead && !c.isReading).toList()
        ..sort((a, b) {
          final s = a.seriesName.compareTo(b.seriesName);
          if (s != 0) return s;
          final ai = double.tryParse(a.issueNumber ?? '') ?? 0;
          final bi = double.tryParse(b.issueNumber ?? '') ?? 0;
          return ai.compareTo(bi);
        }));

  List<Comic> _computeTopRated(List<Comic> comics) =>
      (comics.where((c) => c.starRating > 0).toList()
        ..sort((a, b) => b.starRating.compareTo(a.starRating)));

  (Comic?, String) _computeFeaturedComic(List<Comic> comics) {
    if (comics.isEmpty) return (null, 'SPOTLIGHT');

    // Priority 1: currently reading — feels personal and timely
    final reading = comics
        .where((c) => c.isReading && c.coverImageUrl != null)
        .toList()
      ..sort((a, b) => b.addedDate.compareTo(a.addedDate));
    if (reading.isNotEmpty) return (reading.first, 'CURRENTLY READING');

    // Priority 2: unread issue in a series the user rated 5 stars
    final fiveStarSeries =
        comics.where((c) => c.starRating == 5).map((c) => c.seriesName).toSet();
    final fiveStarUnread = comics
        .where((c) =>
            !c.isRead &&
            !c.isReading &&
            fiveStarSeries.contains(c.seriesName) &&
            c.coverImageUrl != null)
        .toList();
    if (fiveStarUnread.isNotEmpty) {
      final seed =
          DateTime.now().year * 10000 + DateTime.now().month * 100 + DateTime.now().day;
      return (fiveStarUnread[Random(seed).nextInt(fiveStarUnread.length)], 'RECOMMENDED');
    }

    // Priority 3: highest-rated comic with a cover
    final topRated = comics
        .where((c) => c.starRating >= 4 && c.coverImageUrl != null)
        .toList()
      ..sort((a, b) => b.starRating.compareTo(a.starRating));
    if (topRated.isNotEmpty) return (topRated.first, 'TOP RATED');

    // Priority 4: most recently added with a cover
    final recent = comics
        .where((c) => c.coverImageUrl != null)
        .toList()
      ..sort((a, b) => b.addedDate.compareTo(a.addedDate));
    if (recent.isNotEmpty) return (recent.first, 'JUST ADDED');

    // Fallback: daily random
    final seed =
        DateTime.now().year * 10000 + DateTime.now().month * 100 + DateTime.now().day;
    final pool = comics.where((c) => c.coverImageUrl != null).toList();
    final pick = pool.isEmpty ? comics.first : pool[Random(seed).nextInt(pool.length)];
    return (pick, 'YOUR PICK');
  }

  void _updateShelves(List<Comic> comics) {
    _currentlyReading = _computeCurrentlyReading(comics);
    _recentlyAdded    = _computeRecentlyAdded(comics);
    _continueReading  = _computeContinueReading(comics);
    _topRated         = _computeTopRated(comics);
    final (comic, label) = _computeFeaturedComic(comics);
    _featuredComic  = comic;
    _spotlightLabel = label;
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openDrawer() {
    AppHaptics.select();
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _openScanner() async {
    AppHaptics.medium();
    final barcode = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (!mounted || barcode == null) return;

    // Strip supplement for fallback search query (just the main UPC)
    final mainBarcode = barcode.length == 17
        ? barcode.substring(0, 12)
        : barcode.length == 18
            ? barcode.substring(0, 13)
            : barcode;

    // Show a styled loading dialog while we resolve the barcode.
    // A cancel button lets the user abort; a 15-second timeout auto-dismisses.
    bool cancelled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 18),
                Text('Looking up barcode…',
                    style: tUi(15,
                        color: AppColors.textPrimary,
                        weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(mainBarcode,
                    style: tUi(12, color: AppColors.textTertiary)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    cancelled = true;
                    Navigator.pop(dialogCtx);
                  },
                  child: Text('Cancel',
                      style: tUi(14,
                          color: AppColors.accent,
                          weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final comic = await ComicVineService.instance
          .lookupByBarcode(barcode)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (cancelled) return;
      Navigator.pop(context); // dismiss loader

      if (comic != null) {
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ComicDetailScreen(
              comic: comic,
              onUpdated: _silentRefresh,
              mode: ComicDetailMode.preview,
              fromBarcode: true,
              barcode: mainBarcode,
              onWrongComic: (reportData) => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SearchResultsScreen(
                          initialQuery: '',
                          onComicAdded: _silentRefresh,
                          notFoundBarcode: mainBarcode,
                          wrongComicReport: reportData,
                        )),
              ),
            ),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      } else {
        // Could not resolve — open search with an empty query and a banner
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SearchResultsScreen(
                    initialQuery: '',
                    onComicAdded: _silentRefresh,
                    notFoundBarcode: mainBarcode,
                  )),
        );
      }
    } catch (_) {
      if (!mounted) return;
      if (cancelled) return;
      Navigator.pop(context); // dismiss loader
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SearchResultsScreen(
                  initialQuery: '',
                  onComicAdded: _silentRefresh,
                  notFoundBarcode: mainBarcode,
                )),
      );
    }
  }

  void _openSearch() {
    AppHaptics.select();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                SearchResultsScreen(initialQuery: '', onComicAdded: _silentRefresh)));
  }

  void _openComic(Comic comic) {
    AppHaptics.light();
    Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              ComicDetailScreen(comic: comic, onUpdated: _silentRefresh),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ));
  }

  void _drawerNav(VoidCallback action) {
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 250), action);
  }

  void _openWishlist() => _drawerNav(() {
        AppHaptics.select();
        Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const WishlistScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 280),
            )).then((_) => _silentRefresh());
      });

  void _openLibrary() => _drawerNav(() {
        AppHaptics.select();
        Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const LibraryScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 280),
            )).then((_) => _silentRefresh());
      });

  void _openSeriesTracker() => _drawerNav(() {
        AppHaptics.select();
        Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const SeriesTrackerScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 280),
            ));
      });

  void _openSeriesRun(String seriesName, String volumeId) =>
      _drawerNav(() {
        AppHaptics.select();
        Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => SeriesRunScreen(
                seriesName: seriesName,
                volumeId: volumeId,
                onChanged: _load,
              ),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 280),
            ));
      });

  void _openStats() => _drawerNav(() {
        AppHaptics.select();
        Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const StatsScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 280),
            ));
      });

  void _openReadingLog() => _drawerNav(() {
        AppHaptics.select();
        Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const ReadingLogScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 280),
            ));
      });

  void _openSettings() => _drawerNav(() {
        AppHaptics.select();
        Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => SettingsScreen(
                currentLayout: _layout,
                onLayoutChanged: _setLayout,
                onDataChanged: _load,
              ),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 280),
            )).then((_) async {
              await _loadLayout();
              await _loadShelfConfig();
            });
      });

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: _AppDrawer(
        all: _all,
        wishlistCount: _wishlistCount,
        onSearch: () => _drawerNav(_openSearch),
        onSeriesTracker: _openSeriesTracker,
        onWishlist: _openWishlist,
        onLibrary: _openLibrary,
        onStats: _openStats,
        onReadingLog: _openReadingLog,
        onSettings: _openSettings,
        onScan: () => _drawerNav(_openScanner),
        onSeriesRunTap: _openSeriesRun,
      ),
      body: _loading ? _buildGlobalSkeleton() : _buildLayout(),
    );
  }

  Widget _buildLayout() {
    final cb = _LayoutCallbacks(
      onComicTap: _openComic,

      onScanTap: _openScanner,
      onSearchTap: _openSearch,
      onMenuTap: _openDrawer,
      onRefresh: _load,
    );
    switch (_layout) {
      case HomeLayout.featured:
        return _FeaturedLayout(
            all: _all,
            currentlyReading: _currentlyReading,
            recentlyAdded: _recentlyAdded,
            continueReading: _continueReading,
            topRated: _topRated,
            featuredComic: _featuredComic,
            spotlightLabel: _spotlightLabel,

            shelves: _shelves,
            cb: cb);
      case HomeLayout.shelves:
        return _ShelvesLayout(
            all: _all,
            currentlyReading: _currentlyReading,
            recentlyAdded: _recentlyAdded,
            continueReading: _continueReading,
            topRated: _topRated,

            shelves: _shelves,
            cb: cb);
      case HomeLayout.mosaic:
        return _MosaicLayout(
            all: _all,
            currentlyReading: _currentlyReading,
            recentlyAdded: _recentlyAdded,
            continueReading: _continueReading,
            topRated: _topRated,

            shelves: _shelves,
            cb: cb);
    }
  }

  Widget _buildGlobalSkeleton() => Scaffold(
        backgroundColor: AppColors.bg,
        body: CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _SkeletonHeader()),
            SliverToBoxAdapter(child: _SkeletonShelf()),
            SliverToBoxAdapter(child: _SkeletonShelf()),
          ],
        ),
      );
}

// ── Layout callbacks ──────────────────────────────────────────────────────────

class _LayoutCallbacks {
  final void Function(Comic) onComicTap;

  final VoidCallback onScanTap;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;
  final Future<void> Function() onRefresh;

  const _LayoutCallbacks({
    required this.onComicTap,
    required this.onScanTap,
    required this.onSearchTap,
    required this.onMenuTap,
    required this.onRefresh,
  });
}