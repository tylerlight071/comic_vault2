// lib/REST API/screens/stats_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/services/app_settings.dart';
import '../../theme/typography.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';
import '../../theme/app_colors.dart';
import '../../theme/models/comic.dart';
import '../../theme/services/database_service.dart';
import '../../../widgets/pressable.dart';
import '../../../widgets/section_label.dart';

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
  int  _readingGoal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final library  = await DatabaseService.instance.getAllComics();
    final wishlist = await DatabaseService.instance.getWishlist();
    final prefs    = await SharedPreferences.getInstance();
    final goal     = prefs.getInt('reading_goal_$_thisYear') ?? 0;
    if (mounted) {
      setState(() {
        _library     = library;
        _wishlist    = wishlist;
        _readingGoal = goal;
        _loading     = false;
      });
    }
  }

  Future<void> _editGoal() async {
    final ctrl = TextEditingController(
        text: _readingGoal > 0 ? '$_readingGoal' : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reading Goal', style: tUi(17, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How many comics do you want to read in $_thisYear?',
                style: tUi(13,
                    color: AppColors.textSecondary,
                    weight: FontWeight.w400,
                    height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: tUi(16, color: AppColors.textPrimary, weight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: '52',
                hintStyle: tUi(16, color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surface3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          if (_readingGoal > 0)
            TextButton(
              onPressed: () => Navigator.pop(ctx, '0'),
              child: Text('Remove Goal',
                  style: tUi(14,
                      color: AppColors.redDestructive.withOpacity(0.8),
                      weight: FontWeight.w600)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: tUi(14,
                    color: AppColors.textSecondary, weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text('Save',
                style: tUi(14,
                    color: AppColors.textPrimary, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    final parsed = int.tryParse(result.trim()) ?? 0;
    final prefs  = await SharedPreferences.getInstance();
    await prefs.setInt('reading_goal_$_thisYear', parsed);
    setState(() => _readingGoal = parsed);
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

  // ── This-year stats (requires readDate to be populated) ───────────────────

  int get _thisYear => DateTime.now().year;

  List<Comic> get _readThisYear => _library
      .where((c) => c.readDate != null && c.readDate!.year == _thisYear)
      .toList();

  /// Reads per month (Jan=1 … Dec=12) for the current year.
  List<MapEntry<String, int>> get _readByMonth {
    final months = <int, int>{};
    for (final c in _readThisYear) {
      months[c.readDate!.month] = (months[c.readDate!.month] ?? 0) + 1;
    }
    const labels = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months.entries
        .map((e) => MapEntry(labels[e.key], e.value))
        .toList()
      ..sort((a, b) {
        final ai = labels.indexOf(a.key);
        final bi = labels.indexOf(b.key);
        return ai.compareTo(bi);
      });
  }

  // ── Series / publisher / etc. ──────────────────────────────────────────────

  List<Comic> get _loanedComics => _library.where((c) => c.loanedTo != null).toList();

  int    get _pricedCount => _library.where((c) => c.purchasePrice != null).length;
  double get _totalPaid   => _library.fold(0.0, (s, c) => s + (c.purchasePrice ?? 0.0));
  double get _avgPrice {
    final priced = _library.where((c) => c.purchasePrice != null).toList();
    if (priced.isEmpty) return 0;
    return priced.fold(0.0, (s, c) => s + c.purchasePrice!) / priced.length;
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
                    _buildGoalSection(),
                    if (_readThisYear.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _buildThisYear(),
                    ],
                    if (_pricedCount > 0) ...[
                      const SizedBox(height: 28),
                      _buildValueSection(),
                    ],
                    if (_loanedComics.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      SectionLabel('LOANED OUT'),
                      const SizedBox(height: 10),
                      _buildLoanedSection(),
                    ],
                    const SizedBox(height: 28),
                    if (_topSeries.isNotEmpty) ...[
                      SectionLabel('TOP SERIES'),
                      const SizedBox(height: 10),
                      _buildBarChart(_topSeries, barColor: AppColors.gold),
                      const SizedBox(height: 28),
                    ],
                    if (_topPublishers.isNotEmpty) ...[
                      SectionLabel('PUBLISHERS'),
                      const SizedBox(height: 10),
                      _buildBarChart(_topPublishers, barColor: AppColors.accent),
                      const SizedBox(height: 28),
                    ],
                    if (_byDecade.isNotEmpty) ...[
                      SectionLabel('BY DECADE'),
                      const SizedBox(height: 10),
                      _buildBarChart(_byDecade, barColor: AppColors.greenOwned),
                      const SizedBox(height: 28),
                    ],
                    if (_byCondition.isNotEmpty) ...[
                      SectionLabel('CONDITION'),
                      const SizedBox(height: 10),
                      _buildBarChart(_byCondition, barColor: AppColors.redDestructive),
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
              valueColor: const AlwaysStoppedAnimation(AppColors.greenOwned),
              minHeight: 6,
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

  // ── This year ─────────────────────────────────────────────────────────────

  Widget _buildThisYear() {
    final count   = _readThisYear.length;
    final byMonth = _readByMonth;

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
              Text('$count',
                  style: tDisplay(32,
                      weight: FontWeight.w700, letterSpacing: -1.0)),
              const SizedBox(width: 8),
              Text('read in $_thisYear',
                  style: tUi(14,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w400)),
            ],
          ),
          if (byMonth.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionLabel('BY MONTH'),
            const SizedBox(height: 10),
            _buildInlineBarChart(byMonth, barColor: AppColors.accent),
          ],
        ],
      ),
    );
  }

  /// Compact bar chart rendered inline (no outer container — caller wraps it).
  Widget _buildInlineBarChart(List<MapEntry<String, int>> entries,
      {Color barColor = AppColors.textPrimary}) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final max = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Column(
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
              width: 36,
              child: Text(label,
                  style: tUi(12,
                      color: AppColors.textSecondary,
                      weight: FontWeight.w500)),
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
                        color: barColor,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: barColor.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 20,
              child: Text('$count',
                  textAlign: TextAlign.end,
                  style: tUi(12,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w600)),
            ),
          ]),
        );
      }).toList(),
    );
  }

  // ── Bar chart ─────────────────────────────────────────────────────────────

  Widget _buildBarChart(List<MapEntry<String, int>> entries,
      {Color barColor = AppColors.textPrimary}) {
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
                          color: barColor,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
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

  // ── Reading goal ──────────────────────────────────────────────────────────

  Widget _buildGoalSection() {
    final goal  = _readingGoal;
    final count = _readThisYear.length;
    final pct   = goal > 0 ? (count / goal).clamp(0.0, 1.0) : 0.0;
    final done  = goal > 0 && count >= goal;

    return Pressable(
      onTap: _editGoal,
      haptic: HapticStyle.light,
      scaleDown: 0.98,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: goal == 0
            ? Row(children: [
                const Icon(Icons.flag_outlined,
                    color: AppColors.textTertiary, size: 18),
                const SizedBox(width: 10),
                Text('Set a reading goal for $_thisYear',
                    style: tUi(14,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w500)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textDisabled, size: 16),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$count',
                          style: tDisplay(32,
                              weight: FontWeight.w700, letterSpacing: -1.0)),
                      const SizedBox(width: 4),
                      Text(' / $goal',
                          style: tUi(16,
                              color: AppColors.textTertiary,
                              weight: FontWeight.w400)),
                      const SizedBox(width: 6),
                      if (done)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.greenOwnedDim,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Goal reached!',
                              style: tUi(11,
                                  color: AppColors.greenOwned,
                                  weight: FontWeight.w700)),
                        ),
                      const Spacer(),
                      Pressable(
                        onTap: _editGoal,
                        haptic: HapticStyle.light,
                        child: Text('Edit',
                            style: tUi(12,
                                color: AppColors.textTertiary,
                                weight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('comics read in $_thisYear  ·  goal: $goal',
                      style: tUi(12,
                          color: AppColors.textTertiary,
                          weight: FontWeight.w400)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.surface3,
                      valueColor: AlwaysStoppedAnimation(
                          done ? AppColors.greenOwned : AppColors.accent),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Collection value ──────────────────────────────────────────────────────

  Widget _buildValueSection() {
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
          Text('COLLECTION VALUE',
              style: tUi(10,
                  color: AppColors.textTertiary,
                  weight: FontWeight.w700,
                  letterSpacing: 1.6)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${AppSettings.instance.currencySymbol}${_totalPaid.toStringAsFixed(2)}',
                      style: tDisplay(26,
                          weight: FontWeight.w700, letterSpacing: -0.8)),
                  const SizedBox(height: 3),
                  Text('total paid',
                      style: tUi(12,
                          color: AppColors.textTertiary,
                          weight: FontWeight.w400)),
                ],
              ),
            ),
            Container(width: 1, height: 40, color: AppColors.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${AppSettings.instance.currencySymbol}${_avgPrice.toStringAsFixed(2)}',
                        style: tDisplay(26,
                            weight: FontWeight.w700, letterSpacing: -0.8)),
                    const SizedBox(height: 3),
                    Text('avg per comic',
                        style: tUi(12,
                            color: AppColors.textTertiary,
                            weight: FontWeight.w400)),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text('Based on $_pricedCount of $_total comics with a price recorded',
              style: tUi(11,
                  color: AppColors.textDisabled, weight: FontWeight.w400)),
        ],
      ),
    );
  }

  // ── Loaned out ────────────────────────────────────────────────────────────

  Widget _buildLoanedSection() {
    final comics = _loanedComics;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: comics.asMap().entries.map((e) {
          final i     = e.key;
          final comic = e.value;
          final last  = i == comics.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: last
                  ? null
                  : Border(
                      bottom: BorderSide(
                          color: AppColors.border.withOpacity(0.4))),
            ),
            child: Row(children: [
              const Icon(Icons.person_rounded,
                  color: AppColors.gold, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comic.loanedTo!,
                        style: tUi(13,
                            color: AppColors.textPrimary,
                            weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${comic.seriesName}'
                      '${comic.issueNumber != null ? ' #${comic.issueNumber}' : ''}',
                      style: tUi(12,
                          color: AppColors.textTertiary,
                          weight: FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

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
