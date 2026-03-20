// lib/REST API/screens/series_run_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/typography.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';

import '../../theme/app_colors.dart';
import '../../theme/models/comic.dart';
import '../../theme/services/comic_vine_service.dart';
import '../../theme/services/cover_palette_service.dart';
import '../../theme/services/database_service.dart';
import '../../theme/utils/haptics.dart';
import '../../../widgets/pressable.dart';
import 'comic_detail_screen.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class SeriesRunScreen extends StatefulWidget {
  final String seriesName;
  final String volumeId;
  final VoidCallback? onChanged;

  const SeriesRunScreen({
    super.key,
    required this.seriesName,
    required this.volumeId,
    this.onChanged,
  });

  @override
  State<SeriesRunScreen> createState() => _SeriesRunScreenState();
}

class _SeriesRunScreenState extends State<SeriesRunScreen>
    with SingleTickerProviderStateMixin {
  List<Comic> _issues    = [];
  Set<String> _ownedIds   = {};
  Set<String> _wishlistIds = {};
  Set<String> _readIds     = {};
  bool _loading = true;
  String? _error;
  // Fetch progress for large series (null = indeterminate)
  int? _fetchLoaded;
  int? _fetchTotal;

  late final AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  Color _paletteColor = AppColors.textSecondary;

  int get _owned   => _issues.where((i) => _ownedIds.contains(i.comicVineId)).length;
  int get _wanted  => _issues.where((i) => _wishlistIds.contains(i.comicVineId)).length;
  int get _missing => _issues.length - _owned - _wanted;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _progressAnim = const AlwaysStoppedAnimation(0.0);
    _load();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  void _animateProgress() {
    final pct = _issues.isEmpty ? 0.0 : _owned / _issues.length;
    _progressAnim = Tween<double>(begin: 0, end: pct).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOutCubic),
    );
    _progressCtrl
      ..reset()
      ..forward();
  }

  Future<void> _loadPalette() async {
    final cover = _issues
        .where((i) => _ownedIds.contains(i.comicVineId) &&
            i.coverImageUrl != null)
        .map((i) => i.coverImageUrl!)
        .firstOrNull ??
        _issues
            .where((i) => i.coverImageUrl != null)
            .map((i) => i.coverImageUrl!)
            .firstOrNull;

    if (cover == null) return;
    final color = await CoverPaletteService.instance.getColor(cover);
    if (mounted) setState(() => _paletteColor = color);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _fetchLoaded = null; _fetchTotal = null; });
    try {
      // Start all three fetches concurrently — API call and two DB reads are
      // independent so there is no reason to await them sequentially.
      final issuesFuture = ComicVineService.instance.getVolumeIssues(
        widget.volumeId,
        onProgress: (loaded, total) {
          if (mounted && total > 100) {
            setState(() { _fetchLoaded = loaded; _fetchTotal = total; });
          }
        },
      );
      final ownedFuture      = DatabaseService.instance.getOwnedIds();
      final wishlistedFuture = DatabaseService.instance.getWishlistIds();
      final readFuture       = DatabaseService.instance.getReadIds();
      final issues     = await issuesFuture;
      final owned      = await ownedFuture;
      final wishlisted = await wishlistedFuture;
      final read       = await readFuture;
      if (mounted) {
        setState(() {
          _issues      = issues;
          _ownedIds    = owned;
          _wishlistIds = wishlisted;
          _readIds     = read;
          _loading     = false;
        });
        _animateProgress();
        _loadPalette();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    final owned      = await DatabaseService.instance.getOwnedIds();
    final wishlisted = await DatabaseService.instance.getWishlistIds();
    final read       = await DatabaseService.instance.getReadIds();
    if (mounted) {
      setState(() { _ownedIds = owned; _wishlistIds = wishlisted; _readIds = read; });
      _animateProgress();
      _loadPalette();
    }
    widget.onChanged?.call();
  }

  void _openIssue(Comic issue) {
    AppHaptics.light();
    final isOwned = _ownedIds.contains(issue.comicVineId);
    if (isOwned) {
      DatabaseService.instance.getComicByVineId(issue.comicVineId).then((owned) {
        if (!mounted) return;
        Navigator.push(context, _fade(ComicDetailScreen(
          comic: owned ?? issue,
          onUpdated: _refresh,
          mode: ComicDetailMode.owned,
        )));
      });
    } else {
      Navigator.push(context, _fade(ComicDetailScreen(
        comic: issue,
        onUpdated: _refresh,
        mode: ComicDetailMode.preview,
      )));
    }
  }

  PageRouteBuilder _fade(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 260),
      );

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
            _buildLoading()
          else if (_error != null)
            _buildError()
          else ...[
            _buildProgressHeader(),
            _buildLegend(),
            _buildList(),
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
            Text('FULL RUN',
                style: tUi(10,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const SizedBox(height: 2),
            Text(widget.seriesName,
                style: tDisplay(17,
                    weight: FontWeight.w700, letterSpacing: -0.4),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  // ── Progress header ───────────────────────────────────────────────────────
  //
  // Replaces the old stats grid. Shows owned/total as a large fraction,
  // the animated palette-tinted progress bar, and compact chips for
  // wanted + missing below.

  Widget _buildProgressHeader() => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fraction + percentage
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$_owned',
                      style: tDisplay(32,
                          weight: FontWeight.w700, letterSpacing: -1.0)),
                  Text(' / ${_issues.length}',
                      style: tUi(16,
                          color: AppColors.textTertiary,
                          weight: FontWeight.w400)),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (_, __) => Text(
                      '${(_progressAnim.value * 100).round()}%',
                      style: tUi(14,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Animated progress bar
              AnimatedBuilder(
                animation: _progressAnim,
                builder: (_, __) => LayoutBuilder(
                  builder: (_, constraints) => Stack(children: [
                    Container(
                      height: 4,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: AppColors.surface3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      height: 4,
                      width: constraints.maxWidth * _progressAnim.value,
                      decoration: BoxDecoration(
                        color: _owned == _issues.length
                            ? AppColors.greenOwned
                            : _paletteColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 10),

              // Sub-chips
              Row(children: [
                Text('owned',
                    style: tUi(11,
                        color: AppColors.textDisabled,
                        weight: FontWeight.w400)),
                if (_wanted > 0) ...[
                  const SizedBox(width: 14),
                  Container(
                    width: 3, height: 3,
                    decoration: const BoxDecoration(
                      color: AppColors.textDisabled,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('$_wanted wishlisted',
                      style: tUi(11,
                          color: AppColors.gold,
                          weight: FontWeight.w500)),
                ],
                if (_missing > 0) ...[
                  const SizedBox(width: 14),
                  Container(
                    width: 3, height: 3,
                    decoration: const BoxDecoration(
                      color: AppColors.textDisabled,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('$_missing missing',
                      style: tUi(11,
                          color: AppColors.textTertiary,
                          weight: FontWeight.w400)),
                ],
              ]),
            ],
          ),
        ).animate().fadeIn(duration: 380.ms),
      );

  // ── Legend ────────────────────────────────────────────────────────────────

  Widget _buildLegend() => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(children: [
            _legendDot(AppColors.greenOwned),
            const SizedBox(width: 6),
            Text('Owned',
                style: tUi(11, color: AppColors.textTertiary)),
            const SizedBox(width: 16),
            _legendDot(AppColors.gold),
            const SizedBox(width: 6),
            Text('Wishlisted',
                style: tUi(11, color: AppColors.textTertiary)),
            const SizedBox(width: 16),
            _legendDot(AppColors.surface3),
            const SizedBox(width: 6),
            Text('Not owned',
                style: tUi(11, color: AppColors.textTertiary)),
          ]),
        ).animate().fadeIn(duration: 380.ms, delay: 60.ms),
      );

  Widget _legendDot(Color color) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ── Issue list ────────────────────────────────────────────────────────────

  Widget _buildList() => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final issue    = _issues[i];
              final isOwned  = _ownedIds.contains(issue.comicVineId);
              final isWanted = _wishlistIds.contains(issue.comicVineId);
              final isRead   = _readIds.contains(issue.comicVineId);
              return _IssueRow(
                issue:    issue,
                index:    i,
                isOwned:  isOwned,
                isWanted: isWanted,
                isRead:   isRead,
                onTap:    () => _openIssue(issue),
                onToggleRead: isOwned ? () async {
                  final owned = await DatabaseService.instance.getComicByVineId(issue.comicVineId);
                  if (owned == null) return;
                  await DatabaseService.instance.updateComic(
                    owned.copyWith(
                      isRead: !owned.isRead,
                      readDate: !owned.isRead ? DateTime.now() : null,
                      clearReadDate: owned.isRead,
                    ),
                  );
                  await _refresh();
                } : null,
              )
                  .animate(
                      delay: Duration(
                          milliseconds: (i * 30).clamp(0, 400)))
                  .fadeIn(duration: 260.ms)
                  .slideX(
                      begin: 0.03,
                      end: 0,
                      curve: Curves.easeOutCubic);
            },
            childCount: _issues.length,
          ),
        ),
      );

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoading() => SliverToBoxAdapter(
        child: Column(
          children: [
            // Show fetch progress for large series (>100 issues)
            if (_fetchTotal != null && _fetchTotal! > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fetching issues…',
                            style: tUi(12, color: AppColors.textTertiary)),
                        Text('$_fetchLoaded / $_fetchTotal',
                            style: tUi(12, color: AppColors.textTertiary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: _fetchLoaded! / _fetchTotal!,
                        backgroundColor: AppColors.surface2,
                        valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            SizedBox(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Column(
                  children: List.generate(
                    10,
                    (i) => const _SkeletonIssueRow()
                        .animate(
                          delay: Duration(milliseconds: i * 45),
                          onPlay: (c) => c.repeat(),
                        )
                        .shimmer(
                          duration: 1400.ms,
                          color: AppColors.skeletonHighlight.withOpacity(0.3),
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() => SliverFillRemaining(
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
                child: const Icon(Icons.cloud_off_rounded,
                    color: AppColors.textDisabled, size: 32),
              ),
              const SizedBox(height: 24),
              Text('Could not load series',
                  style: tDisplay(20,
                      weight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 10),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: tUi(13,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w400,
                      height: 1.55)),
              const SizedBox(height: 28),
              Pressable(
                onTap: _load,
                haptic: HapticStyle.medium,
                scaleDown: 0.95,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('Try Again',
                      style: tUi(14,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ISSUE ROW  — palette-tinted cover
// ══════════════════════════════════════════════════════════════════════════════

class _IssueRow extends StatefulWidget {
  final Comic issue;
  final int index;
  final bool isOwned;
  final bool isWanted;
  final bool isRead;
  final VoidCallback onTap;
  final Future<void> Function()? onToggleRead;

  const _IssueRow({
    required this.issue,
    required this.index,
    required this.isOwned,
    required this.isWanted,
    required this.isRead,
    required this.onTap,
    this.onToggleRead,
  });

  @override
  State<_IssueRow> createState() => _IssueRowState();
}

class _IssueRowState extends State<_IssueRow> {
  Color _palette  = Colors.black;
  bool  _toggling = false;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(_IssueRow old) {
    super.didUpdateWidget(old);
    if (old.issue.coverImageUrl != widget.issue.coverImageUrl) _loadPalette();
  }

  Future<void> _loadPalette() async {
    final delay = widget.index * 40;
    if (delay > 0) await Future.delayed(Duration(milliseconds: delay));
    if (!mounted) return;
    final c = await CoverPaletteService.instance
        .getColor(widget.issue.coverImageUrl);
    if (mounted) setState(() => _palette = c);
  }

  @override
  Widget build(BuildContext context) {
    final isOwned  = widget.isOwned;
    final isWanted = widget.isWanted;
    final issue    = widget.issue;

    final borderColor = isOwned
        ? AppColors.green_(0.2)
        : isWanted
            ? AppColors.gold_(0.15)
            : AppColors.border;

    final labelColor = isOwned
        ? AppColors.greenOwned
        : isWanted
            ? AppColors.gold
            : AppColors.textTertiary;

    final row = Pressable(
      onTap: widget.onTap,
      haptic: HapticStyle.light,
      scaleDown: 0.97,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          // Status stripe
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: isOwned
                  ? AppColors.greenOwned
                  : isWanted
                      ? AppColors.gold
                      : Colors.transparent,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14)),
            ),
          ),

          // Cover with palette right-edge bleed
          SizedBox(
            width: 54,
            height: 80,
            child: Stack(fit: StackFit.expand, children: [
              issue.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: issue.coverImageUrl!,
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
                            color: AppColors.textDisabled, size: 18),
                      ),
                    ),
              // Palette bleed into row body
              Positioned(
                top: 0, right: 0, bottom: 0,
                width: 28,
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
                if (issue.issueNumber != null)
                  Text(
                    'Issue #${issue.issueNumber}',
                    style: tUi(10,
                        color: labelColor,
                        weight: FontWeight.w700,
                        letterSpacing: 0.4),
                  ),
                const SizedBox(height: 3),
                Text(
                  issue.title.isNotEmpty ? issue.title : issue.seriesName,
                  style: tUi(13,
                      color: isOwned
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      weight: isOwned
                          ? FontWeight.w600
                          : FontWeight.w500,
                      height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (issue.publicationYear != null) ...[
                  const SizedBox(height: 4),
                  Text('${issue.publicationYear}',
                      style: tUi(11,
                          color: AppColors.textDisabled,
                          weight: FontWeight.w400)),
                ],
              ],
            ),
          ),

          // Status icon / read indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _toggling
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.greenOwned,
                    ),
                  )
                : Icon(
                    isOwned
                        ? (widget.isRead
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded)
                        : isWanted
                            ? Icons.bookmark_rounded
                            : Icons.add_circle_outline_rounded,
                    color: isOwned
                        ? (widget.isRead
                            ? AppColors.greenOwned
                            : AppColors.textDisabled)
                        : isWanted
                            ? AppColors.gold
                            : AppColors.surface3,
                    size: 22,
                  ),
          ),
        ]),
      ),
    );

    if (!isOwned || widget.onToggleRead == null) return row;

    return Dismissible(
      key: ValueKey('read_toggle_${widget.issue.comicVineId}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        if (_toggling) return false;
        setState(() => _toggling = true);
        try {
          await widget.onToggleRead!();
        } finally {
          if (mounted) setState(() => _toggling = false);
        }
        return false; // never actually dismiss — just snap back
      },
      background: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          color: widget.isRead
              ? AppColors.surface3
              : AppColors.greenOwned.withOpacity(0.12),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              widget.isRead
                  ? Icons.radio_button_unchecked_rounded
                  : Icons.check_rounded,
              color: widget.isRead
                  ? AppColors.textDisabled
                  : AppColors.greenOwned,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              widget.isRead ? 'Mark unread' : 'Mark read',
              style: tUi(13,
                  color: widget.isRead
                      ? AppColors.textDisabled
                      : AppColors.greenOwned,
                  weight: FontWeight.w600),
            ),
          ]),
        ),
      ),
      child: row,
    );
  }
}

// ── Skeleton issue row ────────────────────────────────────────────────────────

class _SkeletonIssueRow extends StatelessWidget {
  const _SkeletonIssueRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Stripe placeholder
        Container(
          width: 4,
          height: 80,
          decoration: const BoxDecoration(
            color: AppColors.surface2,
            borderRadius:
                BorderRadius.horizontal(left: Radius.circular(14)),
          ),
        ),
        // Cover placeholder
        Container(width: 54, color: AppColors.skeletonBase),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  height: 10, width: 60,
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
                  height: 10, width: 40,
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