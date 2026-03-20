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
import '../../../theme/utils/haptics.dart';
import 'home_typography.dart';
import '../scanner_screen.dart';
import '../search_results_screen.dart';
import '../comic_detail_screen.dart';
import '../wishlist_screen.dart';
import '../settings_screen.dart';
import '../series_tracker_screen.dart';
import '../library_screen.dart';
import '../series_run_screen.dart';

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
  HomeLayout _layout = HomeLayout.featured;

  // Cached shelf lists — computed once after each load, not on every build().
  List<Comic> _recentlyAdded  = [];
  List<Comic> _continueReading = [];
  List<Comic> _topRated        = [];
  Comic?      _featuredComic;

  // How many comics to show in the Recently Added shelf. Enough to give a
  // meaningful snapshot without the row feeling endless.
  static const int _recentlyAddedLimit = 6;

  @override
  void initState() {
    super.initState();
    _loadLayout();
    _load();
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('home_layout') ?? 0;
    if (mounted) setState(() => _layout = HomeLayout.values[idx.clamp(0, 2)]);
  }

  Future<void> _setLayout(HomeLayout l) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('home_layout', l.index);
    if (mounted) setState(() => _layout = l);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final comics = await DatabaseService.instance.getAllComics();
    if (mounted) {
      setState(() {
        _all = comics;
        _loading = false;
        _updateShelves(comics);
      });
      _warmPalette(comics);
    }
  }

  /// Refreshes data without showing the loading skeleton — used after edits or
  /// returning from sub-screens so the home screen stays visible while updating.
  Future<void> _silentRefresh() async {
    final comics = await DatabaseService.instance.getAllComics();
    if (mounted) {
      setState(() {
        _all = comics;
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
 
  for (var i = 0; i < urls.length; i++) {
    Future.delayed(Duration(milliseconds: i * 60), () {
      if (mounted) CoverPaletteService.instance.getColor(urls[i]);
    });
  }
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

  List<Comic> _computeContinueReading(List<Comic> comics) =>
      (comics.where((c) => !c.isRead).toList()
        ..sort((a, b) => b.addedDate.compareTo(a.addedDate)));

  List<Comic> _computeTopRated(List<Comic> comics) =>
      (comics.where((c) => c.starRating > 0).toList()
        ..sort((a, b) => b.starRating.compareTo(a.starRating)));

  Comic? _computeFeaturedComic(List<Comic> comics) {
    if (comics.isEmpty) return null;
    final candidates = comics.where((c) => c.coverImageUrl != null).toList();
    final pool = candidates.isNotEmpty ? candidates : comics;
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    return pool[Random(seed).nextInt(pool.length)];
  }

  void _updateShelves(List<Comic> comics) {
    _recentlyAdded   = _computeRecentlyAdded(comics);
    _continueReading = _computeContinueReading(comics);
    _topRated        = _computeTopRated(comics);
    _featuredComic   = _computeFeaturedComic(comics);
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
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SearchResultsScreen(
                initialQuery: barcode, onComicAdded: _silentRefresh)));
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
            )).then((_) => _loadLayout());
      });

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: _AppDrawer(
        all: _all,
        onSearch: () => _drawerNav(_openSearch),
        onSeriesTracker: _openSeriesTracker,
        onWishlist: _openWishlist,
        onLibrary: _openLibrary,
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
            recentlyAdded: _recentlyAdded,
            continueReading: _continueReading,
            topRated: _topRated,
            featuredComic: _featuredComic,
            cb: cb);
      case HomeLayout.shelves:
        return _ShelvesLayout(
            all: _all,
            recentlyAdded: _recentlyAdded,
            continueReading: _continueReading,
            topRated: _topRated,
            cb: cb);
      case HomeLayout.mosaic:
        return _MosaicLayout(
            all: _all,
            recentlyAdded: _recentlyAdded,
            continueReading: _continueReading,
            topRated: _topRated,
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