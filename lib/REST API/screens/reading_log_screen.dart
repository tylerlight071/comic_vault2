// lib/REST API/screens/reading_log_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/typography.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';
import '../../theme/app_colors.dart';
import '../../theme/models/comic.dart';
import '../../theme/services/database_service.dart';
import '../../theme/utils/haptics.dart';
import '../../../widgets/pressable.dart';
import 'comic_detail/comic_detail_screen.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class ReadingLogScreen extends StatefulWidget {
  const ReadingLogScreen({super.key});

  @override
  State<ReadingLogScreen> createState() => _ReadingLogScreenState();
}

class _ReadingLogScreenState extends State<ReadingLogScreen> {
  List<Comic> _read = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DatabaseService.instance.getAllComics();
    // Include every read comic regardless of whether readDate is populated.
    // Comics added before v7 (which introduced readDate) have isRead=true but
    // readDate=null — they belong in the log too, just without a known date.
    final read = all.where((c) => c.isRead).toList()
      ..sort((a, b) {
        // Comics with a known date sort newest-first; unknowns go last.
        if (a.readDate == null && b.readDate == null) return 0;
        if (a.readDate == null) return 1;
        if (b.readDate == null) return -1;
        return b.readDate!.compareTo(a.readDate!);
      });
    if (mounted) setState(() { _read = read; _loading = false; });
  }

  // ── Grouping ──────────────────────────────────────────────────────────────

  static const _unknownDateLabel = 'Unknown Date';

  /// Groups comics into month buckets: key = 'MMMM yyyy' (e.g. 'March 2026').
  /// Comics with no readDate are placed in a final 'Unknown Date' bucket.
  List<_MonthGroup> get _groups {
    final map = <String, List<Comic>>{};
    for (final c in _read) {
      final key = c.readDate != null ? _monthKey(c.readDate!) : _unknownDateLabel;
      map.putIfAbsent(key, () => []).add(c);
    }
    // Pull out the unknown-date bucket so it always sorts last.
    final unknown = map.remove(_unknownDateLabel);
    final groups = map.entries
        .map((e) => _MonthGroup(label: e.key, comics: e.value))
        .toList();
    if (unknown != null) {
      groups.add(_MonthGroup(label: _unknownDateLabel, comics: unknown));
    }
    return groups;
  }

  String _monthKey(DateTime d) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month]} ${d.year}';
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openComic(Comic comic) {
    AppHaptics.light();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            ComicDetailScreen(comic: comic, onUpdated: _load),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
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
                    color: AppColors.textTertiary, strokeWidth: 1.5),
              ),
            )
          else if (_read.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            _buildLog(),
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
                  color: AppColors.textSecondary,
                  size: 16,
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
            Text('Reading Log',
                style: tDisplay(17,
                    weight: FontWeight.w700, letterSpacing: -0.4)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_read.length} read',
                style: tUi(12,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w500),
              ),
            ),
          ),
        ],
      );

  // ── Log list ──────────────────────────────────────────────────────────────

  Widget _buildLog() {
    final groups = _groups;
    // Build a flat list of section headers + comic rows for SliverList
    final items = <_LogItem>[];
    for (final g in groups) {
      items.add(_LogItem.header(g.label, g.comics.length));
      for (final c in g.comics) {
        items.add(_LogItem.comic(c));
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final item = items[i];
            if (item.isHeader) {
              return _MonthHeader(label: item.label!, count: item.count!)
                  .animate(delay: Duration(milliseconds: (i * 20).clamp(0, 300)))
                  .fadeIn(duration: 260.ms);
            }
            return _LogRow(
              comic: item.comic!,
              onTap: () => _openComic(item.comic!),
            )
                .animate(
                    delay: Duration(milliseconds: (i * 25).clamp(0, 400)))
                .fadeIn(duration: 260.ms)
                .slideX(begin: 0.03, end: 0, curve: Curves.easeOutCubic);
          },
          childCount: items.length,
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.menu_book_rounded,
                    color: AppColors.textDisabled, size: 32),
              ),
              const SizedBox(height: 24),
              Text('Nothing read yet',
                  style: tDisplay(20, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                'Mark comics as read in your\nlibrary to see them here.',
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

// ── Data helpers ──────────────────────────────────────────────────────────────

class _MonthGroup {
  final String label;
  final List<Comic> comics;
  const _MonthGroup({required this.label, required this.comics});
}

class _LogItem {
  final bool isHeader;
  final String? label;
  final int? count;
  final Comic? comic;

  const _LogItem._({
    required this.isHeader,
    this.label,
    this.count,
    this.comic,
  });

  factory _LogItem.header(String label, int count) =>
      _LogItem._(isHeader: true, label: label, count: count);

  factory _LogItem.comic(Comic comic) =>
      _LogItem._(isHeader: false, comic: comic);
}

// ── Month header ──────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final String label;
  final int count;

  const _MonthHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label,
              style: tDisplay(15,
                  weight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(width: 8),
          Text('$count issue${count == 1 ? '' : 's'}',
              style:
                  tUi(11, color: AppColors.textTertiary, weight: FontWeight.w400)),
        ],
      ),
    );
  }
}

// ── Log row ───────────────────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  final Comic comic;
  final VoidCallback onTap;

  const _LogRow({required this.comic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: HapticStyle.light,
      scaleDown: 0.97,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          // Cover thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
            child: SizedBox(
              width: 56,
              height: 80,
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
                      child: const Icon(Icons.image_not_supported_rounded,
                          color: AppColors.textDisabled, size: 20),
                    ),
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comic.seriesName,
                      style: tUi(11,
                          color: AppColors.textTertiary,
                          weight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    comic.issueNumber != null
                        ? '${comic.title}  #${comic.issueNumber}'
                        : comic.title,
                    style: tUi(13,
                        color: AppColors.textPrimary,
                        weight: FontWeight.w600,
                        height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (comic.starRating > 0) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < comic.starRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: i < comic.starRating
                              ? AppColors.gold
                              : AppColors.textDisabled,
                          size: 12,
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),

          // Date badge
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: comic.readDate != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          comic.readDate!.day.toString().padLeft(2, '0'),
                          style: tDisplay(18,
                              weight: FontWeight.w700,
                              letterSpacing: -0.5)),
                      Text(_shortMonth(comic.readDate!),
                          style: tUi(10,
                              color: AppColors.textTertiary,
                              weight: FontWeight.w500,
                              letterSpacing: 0.5)),
                    ],
                  )
                : const Icon(Icons.help_outline_rounded,
                    color: AppColors.textDisabled, size: 18),
          ),
        ]),
      ),
    );
  }

  String _shortMonth(DateTime d) {
    const m = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return m[d.month];
  }
}
