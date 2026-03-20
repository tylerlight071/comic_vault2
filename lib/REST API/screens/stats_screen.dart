// lib/REST API/screens/stats_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/typography.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';
import '../../theme/app_colors.dart';
import '../../theme/models/comic.dart';
import '../../theme/services/database_service.dart';
import '../../../widgets/pressable.dart';

// ─────────────────────────────────────────────────────────────────────────────

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Comic> _library  = [];
  List<Comic> _wishlist = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final library  = await DatabaseService.instance.getAllComics();
    final wishlist = await DatabaseService.instance.getWishlist();
    if (mounted) {
      setState(() {
        _library  = library;
        _wishlist = wishlist;
        _loading  = false;
      });
    }
  }

  // ── Derived stats ─────────────────────────────────────────────────────────

  int get _total    => _library.length;
  int get _read     => _library.where((c) => c.isRead).length;
  int get _reading  => _library.where((c) => c.isReading).length;
  int get _rated    => _library.where((c) => c.starRating > 0).length;
  int get _wishCount => _wishlist.length;

  double get _avgRating {
    final rated = _library.where((c) => c.starRating > 0).toList();
    if (rated.isEmpty) return 0;
    return rated.map((c) => c.starRating).reduce((a, b) => a + b) / rated.length;
  }

  int get _seriesCount => _library.map((c) => c.seriesName).toSet().length;
  int get _publisherCount =>
      _library.where((c) => c.publisher != null).map((c) => c.publisher!).toSet().length;

  /// Top 5 series by issue count.
  List<MapEntry<String, int>> get _topSeries {
    final map = <String, int>{};
    for (final c in _library) {
      map[c.seriesName] = (map[c.seriesName] ?? 0) + 1;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  /// Top 5 publishers by issue count.
  List<MapEntry<String, int>> get _topPublishers {
    final map = <String, int>{};
    for (final c in _library) {
      if (c.publisher != null && c.publisher!.isNotEmpty) {
        map[c.publisher!] = (map[c.publisher!] ?? 0) + 1;
      }
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  /// Breakdown by decade.
  List<MapEntry<String, int>> get _byDecade {
    final map = <String, int>{};
    for (final c in _library) {
      if (c.publicationYear != null) {
        final decade = '${(c.publicationYear! ~/ 10) * 10}s';
        map[decade] = (map[decade] ?? 0) + 1;
      }
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  /// Condition breakdown.
  List<MapEntry<String, int>> get _byCondition {
    final map = <String, int>{};
    for (final c in _library) {
      if (c.condition != null && c.condition!.isNotEmpty) {
        map[c.condition!] = (map[c.condition!] ?? 0) + 1;
      }
    }
    const order = ['NM', 'VF', 'FN', 'VG', 'G', 'FR'];
    final entries = map.entries.toList()
      ..sort((a, b) => order.indexOf(a.key).compareTo(order.indexOf(b.key)));
    return entries;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BottomBouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.textTertiary,
                  strokeWidth: 1.5,
                ),
              ),
            )
          else if (_total == 0)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildSummaryGrid(),
                    const SizedBox(height: 28),
                    _buildReadingProgress(),
                    const SizedBox(height: 28),
                    if (_topSeries.isNotEmpty) ...[
                      _sectionLabel('TOP SERIES'),
                      const SizedBox(height: 10),
                      _buildBarChart(_topSeries),
                      const SizedBox(height: 28),
                    ],
                    if (_topPublishers.isNotEmpty) ...[
                      _sectionLabel('PUBLISHERS'),
                      const SizedBox(height: 10),
                      _buildBarChart(_topPublishers),
                      const SizedBox(height: 28),
                    ],
                    if (_byDecade.isNotEmpty) ...[
                      _sectionLabel('BY DECADE'),
                      const SizedBox(height: 10),
                      _buildBarChart(_byDecade),
                      const SizedBox(height: 28),
                    ],
                    if (_byCondition.isNotEmpty) ...[
                      _sectionLabel('CONDITION'),
                      const SizedBox(height: 10),
                      _buildBarChart(_byCondition),
                    ],
                  ],
                ),
              ),
            ),
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
          child: Container(height: 1, color: AppColors.border.withOpacity(0.5)),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Pressable(
            onTap: () => Navigator.pop(context),
            scaleDown: 0.88,
            child: Container(
              width: 36,
              height: 36,
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
            Text('COLLECTION',
                style: tUi(10,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const SizedBox(height: 2),
            Text('Stats',
                style: tDisplay(17, weight: FontWeight.w700, letterSpacing: -0.4)),
          ],
        ),
      );

  // ── Summary grid ──────────────────────────────────────────────────────────

  Widget _buildSummaryGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.2,
      children: [
        _statCard('$_total', 'Comics'),
        _statCard('$_seriesCount', 'Series'),
        _statCard('$_publisherCount', 'Publishers'),
        _statCard('$_read', 'Read'),
        _statCard('$_reading', 'Reading'),
        _statCard('$_wishCount', 'Wishlist'),
      ],
    );
  }

  Widget _statCard(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: tDisplay(24,
                    weight: FontWeight.w700, letterSpacing: -0.8)),
            const SizedBox(height: 3),
            Text(label,
                style: tUi(11,
                    color: AppColors.textTertiary, weight: FontWeight.w500)),
          ],
        ),
      );

  // ── Reading progress ──────────────────────────────────────────────────────

  Widget _buildReadingProgress() {
    final pct = _total == 0 ? 0.0 : _read / _total;
    final pctInt = (pct * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$pctInt%',
                  style: tDisplay(32,
                      weight: FontWeight.w700, letterSpacing: -1.0)),
              const SizedBox(width: 8),
              Text('read',
                  style: tUi(14,
                      color: AppColors.textTertiary, weight: FontWeight.w400)),
              const Spacer(),
              Text('$_read / $_total',
                  style: tUi(13,
                      color: AppColors.textSecondary, weight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.surface3,
              valueColor: const AlwaysStoppedAnimation(AppColors.textPrimary),
              minHeight: 4,
            ),
          ),
          if (_rated > 0) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
              const SizedBox(width: 5),
              Text(
                '${_avgRating.toStringAsFixed(1)} avg · $_rated rated',
                style: tUi(12,
                    color: AppColors.textTertiary, weight: FontWeight.w500),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Bar chart ─────────────────────────────────────────────────────────────

  Widget _buildBarChart(List<MapEntry<String, int>> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final max = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final i     = entry.key;
          final label = entry.value.key;
          final count = entry.value.value;
          final frac  = max == 0 ? 0.0 : count / max;
          final isLast = i == entries.length - 1;

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: Row(children: [
              SizedBox(
                width: 80,
                child: Text(
                  label,
                  style: tUi(12,
                      color: AppColors.textSecondary,
                      weight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(children: [
                    Container(height: 6, color: AppColors.surface3),
                    FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  textAlign: TextAlign.end,
                  style: tUi(12,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w600),
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(text,
            style: tUi(10,
                color: AppColors.textTertiary,
                weight: FontWeight.w700,
                letterSpacing: 1.6)),
      );

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: AppColors.textDisabled, size: 52),
              const SizedBox(height: 20),
              Text('No data yet',
                  style: tDisplay(22, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                'Add comics to your library\nto see your stats here.',
                textAlign: TextAlign.center,
                style: tUi(14,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w400,
                    height: 1.6),
              ),
            ],
          ),
        ),
      );
}
