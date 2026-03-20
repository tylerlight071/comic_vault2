// lib/REST API/screens/search_results_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
import '../../../widgets/skeleton_box.dart';
import 'comic_detail_screen.dart';

// ── Suggestion model ──────────────────────────────────────────────────────────

class _SeriesSuggestion {
  final String seriesName;
  final String? publisher;
  final int? startYear;
  final String searchQuery;

  const _SeriesSuggestion({
    required this.seriesName,
    this.publisher,
    this.startYear,
    required this.searchQuery,
  });

  String get displayLabel {
    final parts = <String>[seriesName];
    if (publisher != null && publisher!.isNotEmpty) parts.add(publisher!);
    if (startYear != null) parts.add('$startYear');
    return parts.join(' · ');
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SearchResultsScreen extends StatefulWidget {
  final String initialQuery;
  final VoidCallback onComicAdded;
  final String? notFoundBarcode;
  final Map<String, dynamic>? wrongComicReport;

  const SearchResultsScreen({
    super.key,
    required this.initialQuery,
    required this.onComicAdded,
    this.notFoundBarcode,
    this.wrongComicReport,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _queryCtrl;
  final FocusNode _focusNode = FocusNode();

  List<Comic> _results = [];
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _lastQuery = '';

  List<_SeriesSuggestion> _suggestions = [];
  bool _showSuggestions = false;

  Timer? _debounce;
  static const int _minCharsForLiveSearch = 3;
  static const int _debounceMs = 600;

  List<Map<String, dynamic>> _searchHistory = [];

  // Filters
  bool _includeWishlist = true;
  int? _minRating;
  bool? _isRead;

  Set<String> _ownedIds   = {};
  Set<String> _wishlistIds = {};

  Map<String, dynamic>? _pendingReport;
  String? _pendingBarcode; // barcode that couldn't be resolved — awaiting user mapping

  static const int _pageSize = 20;

  bool get _hasActiveFilters =>
      !_includeWishlist || _minRating != null || _isRead != null;

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController(text: widget.initialQuery);
    _queryCtrl.addListener(_onQueryChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
    _pendingReport = widget.wrongComicReport;
    _pendingBarcode = widget.notFoundBarcode;
    _loadStatus();
    _loadSearchHistory();
    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _search(widget.initialQuery));
    } else if (widget.notFoundBarcode != null) {
      // Barcode scan failed — focus the field so the user can type immediately
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.removeListener(_onQueryChanged);
    _queryCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final owned      = await DatabaseService.instance.getOwnedIds();
    final wishlisted = await DatabaseService.instance.getWishlistIds();
    if (mounted) {
      setState(() {
        _ownedIds    = owned;
        _wishlistIds = wishlisted;
      });
    }
  }

  Future<void> _loadSearchHistory() async {
    final history = await DatabaseService.instance.getSearchHistory();
    if (mounted) setState(() => _searchHistory = history);
  }

  // ── Query listener ────────────────────────────────────────────────────────

  void _onQueryChanged() {
    final q = _queryCtrl.text.trim();

    if (q.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _results = [];
        _total = 0;
        _suggestions = [];
        _showSuggestions = false;
        _lastQuery = '';
        _error = null;
      });
      return;
    }

    if (q.length < _minCharsForLiveSearch) {
      _debounce?.cancel();
      setState(() {
        _results = [];
        _total = 0;
        _suggestions = [];
        _showSuggestions = false;
        _error = null;
      });
      return;
    }

    if (q == _lastQuery) return;
    if (!_loading) setState(() => _error = null);

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: _debounceMs),
      () => _search(q, fromLiveTyping: true),
    );
  }

  // ── Suggestions ───────────────────────────────────────────────────────────

  void _buildSuggestionsFromResults(List<Comic> results) {
    final seen        = <String>{};
    final suggestions = <_SeriesSuggestion>[];

    for (final comic in results) {
      final key = comic.seriesName.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);

      final years = results
          .where((c) => c.seriesName.trim().toLowerCase() == key)
          .where((c) => c.publicationYear != null)
          .map((c) => c.publicationYear!)
          .toList()
        ..sort();

      suggestions.add(_SeriesSuggestion(
        seriesName: comic.seriesName,
        publisher: comic.publisher,
        startYear: years.isNotEmpty ? years.first : null,
        searchQuery: comic.seriesName,
      ));
    }

    setState(() {
      _suggestions    = suggestions;
      _showSuggestions = suggestions.length > 1;
    });
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> _search(String query, {bool fromLiveTyping = false}) async {
    if (query.trim().isEmpty) return;
    _debounce?.cancel();

    if (!fromLiveTyping) {
      _focusNode.unfocus();
      AppHaptics.select();
    }

    setState(() {
      _loading         = true;
      _error           = null;
      _results         = [];
      _total           = 0;
      _lastQuery       = query.trim();
      _showSuggestions = false;
    });

    final q = query.trim();

    try {
      final localResults = await DatabaseService.instance.searchComics(
        q,
        includeWishlist: _includeWishlist,
        minRating: _minRating,
        isRead: _isRead,
        limit: _pageSize,
      );

      List<Comic> onlineResults = [];
      int onlineTotal = 0;
      if (localResults.length < _pageSize) {
        final res = await ComicVineService.instance
            .search(q, limit: _pageSize - localResults.length);
        onlineResults = res.comics;
        onlineTotal   = res.total;
      }

      final all = [...localResults, ...onlineResults];

      if (mounted) {
        setState(() {
          _results = all;
          _total   = localResults.length + onlineTotal;
          _loading = false;
        });
        _buildSuggestionsFromResults(all);
        await DatabaseService.instance.addSearchHistory(q, all.length);
        _loadSearchHistory();
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

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    AppHaptics.light();
    setState(() => _loadingMore = true);
    try {
      final localResults = await DatabaseService.instance.searchComics(
        _lastQuery,
        includeWishlist: _includeWishlist,
        minRating: _minRating,
        isRead: _isRead,
        limit: 1000,
      );
      final onlineOffset = _results.length - localResults.length;
      if (onlineOffset >= 0) {
        final res = await ComicVineService.instance
            .search(_lastQuery, offset: onlineOffset, limit: _pageSize);
        if (mounted) {
          setState(() {
            _results.addAll(res.comics);
            _loadingMore = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingMore = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ── Filter sheet ──────────────────────────────────────────────────────────

  void _openFilterSheet() {
    AppHaptics.select();
    var tempIncludeWishlist = _includeWishlist;
    var tempMinRating       = _minRating;
    var tempIsRead          = _isRead;

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
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
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

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                child: Row(children: [
                  Text('Filter Results',
                      style: tDisplay(18,
                          weight: FontWeight.w700, letterSpacing: -0.3)),
                  const Spacer(),
                  if (tempMinRating != null ||
                      tempIsRead != null ||
                      !tempIncludeWishlist)
                    Pressable(
                      onTap: () {
                        AppHaptics.light();
                        setSheetState(() {
                          tempIncludeWishlist = true;
                          tempMinRating       = null;
                          tempIsRead          = null;
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
                ]),
              ),

              Divider(
                  height: 1,
                  color: AppColors.border.withOpacity(0.5),
                  indent: 20,
                  endIndent: 20),

              const SizedBox(height: 20),

              // Show section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('SHOW',
                    style: tUi(10,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w700,
                        letterSpacing: 1.4)),
              ),
              const SizedBox(height: 10),
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
                    children: [
                      _sheetSegment('All', tempIsRead == null,
                          isFirst: true,
                          onTap: () => setSheetState(() => tempIsRead = null)),
                      _sheetSegment('Read', tempIsRead == true,
                          onTap: () =>
                              setSheetState(() => tempIsRead = true)),
                      _sheetSegment('Unread', tempIsRead == false,
                          isLast: true,
                          onTap: () =>
                              setSheetState(() => tempIsRead = false)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Min rating section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('MINIMUM RATING',
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
                  children: [
                    _sheetChip(
                      label: 'Any',
                      active: tempMinRating == null,
                      onTap: () =>
                          setSheetState(() => tempMinRating = null),
                    ),
                    ...[1, 2, 3, 4, 5].map((r) => _sheetChip(
                          label: '${'★' * r}',
                          active: tempMinRating == r,
                          onTap: () => setSheetState(() =>
                              tempMinRating = tempMinRating == r ? null : r),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Include wishlist toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Pressable(
                  onTap: () => setSheetState(
                      () => tempIncludeWishlist = !tempIncludeWishlist),
                  haptic: HapticStyle.light,
                  scaleDown: 0.98,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: tempIncludeWishlist
                          ? AppColors.surface2
                          : AppColors.surface1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tempIncludeWishlist
                            ? AppColors.borderFocus
                            : AppColors.border,
                      ),
                    ),
                    child: Row(children: [
                      Icon(Icons.bookmark_rounded,
                          color: tempIncludeWishlist
                              ? AppColors.gold
                              : AppColors.textDisabled,
                          size: 18),
                      const SizedBox(width: 12),
                      Text('Include Wishlist',
                          style: tUi(14,
                              color: tempIncludeWishlist
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              weight: FontWeight.w500)),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: tempIncludeWishlist
                              ? AppColors.textPrimary
                              : AppColors.surface3,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: tempIncludeWishlist
                                  ? Colors.transparent
                                  : AppColors.border),
                        ),
                        child: tempIncludeWishlist
                            ? Icon(Icons.check_rounded,
                                color: AppColors.bg, size: 14)
                            : null,
                      ),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Apply button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Pressable(
                  onTap: () {
                    AppHaptics.medium();
                    setState(() {
                      _includeWishlist = tempIncludeWishlist;
                      _minRating       = tempMinRating;
                      _isRead          = tempIsRead;
                    });
                    Navigator.pop(ctx);
                    if (_lastQuery.isNotEmpty) _search(_lastQuery);
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

  // ── Sheet helpers ─────────────────────────────────────────────────────────

  Widget _sheetSegment(String label, bool active,
      {bool isFirst = false, bool isLast = false, required VoidCallback onTap}) {
    return Expanded(
      child: Pressable(
        onTap: () {
          AppHaptics.light();
          onTap();
        },
        haptic: HapticStyle.none,
        scaleDown: 0.96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: active ? AppColors.surface3 : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left:  isFirst ? const Radius.circular(10) : Radius.zero,
              right: isLast  ? const Radius.circular(10) : Radius.zero,
            ),
            border: active
                ? Border.all(color: AppColors.borderFocus)
                : null,
          ),
          child: Center(
            child: Text(label,
                style: tUi(13,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    weight:
                        active ? FontWeight.w600 : FontWeight.w400)),
          ),
        ),
      ),
    );
  }

  Widget _sheetChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) =>
      Pressable(
        onTap: () {
          AppHaptics.light();
          onTap();
        },
        haptic: HapticStyle.none,
        scaleDown: 0.94,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.surface3 : AppColors.surface1,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  active ? AppColors.borderFocus : AppColors.border,
            ),
          ),
          child: Text(label,
              style: tUi(13,
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  weight: active
                      ? FontWeight.w600
                      : FontWeight.w400)),
        ),
      );

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openDetail(Comic comic) {
    AppHaptics.light();
    // If a barcode was unresolved, map it to this comic
    if (_pendingBarcode != null) {
      final barcode = _pendingBarcode!;
      setState(() => _pendingBarcode = null);
      DatabaseService.instance.mapBarcodeToComic(barcode, comic.comicVineId);
      // Only send the "new mapping" log if this isn't a wrong-comic correction
      // (wrong-comic corrections get their own follow-up message below)
      if (_pendingReport == null) {
        _sendNewBarcodeMappingLog(barcode, comic);
      }
    }

    // If this selection follows a wrong-comic report, send the follow-up
    if (_pendingReport != null) {
      _sendCorrectComicFollowUp(_pendingReport!, comic);
      setState(() => _pendingReport = null);
    }

    final isOwned = _ownedIds.contains(comic.comicVineId);
    if (isOwned) {
      DatabaseService.instance.getComicByVineId(comic.comicVineId).then((owned) {
        if (!mounted) return;
        Navigator.push(context, _fade(ComicDetailScreen(
          comic: owned ?? comic,
          onUpdated: () { _loadStatus(); widget.onComicAdded(); },
          mode: ComicDetailMode.owned,
        )));
      });
    } else {
      Navigator.push(context, _fade(ComicDetailScreen(
        comic: comic,
        onUpdated: () { _loadStatus(); widget.onComicAdded(); },
        mode: ComicDetailMode.preview,
      )));
    }
  }

  static const String _reportWebhookUrl =
      'https://discord.com/api/webhooks/1484505399796301854/nDqqB2-mpQ3PEi6CdsOvztDsMUpRUNBHTFsXO7jaUtlqWmgiNZjmper1UctNV0-PfG27';

  void _sendNewBarcodeMappingLog(String barcode, Comic comic) async {
    final label =
        '${comic.seriesName} #${comic.issueNumber ?? "?"} — ${comic.title}';
    try {
      await http
          .post(
            Uri.parse(_reportWebhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'embeds': [
                {
                  'title': '🔗 New barcode mapping',
                  'color': 0x3498DB,
                  'fields': [
                    {'name': 'Barcode', 'value': barcode, 'inline': true},
                    {'name': 'Mapped to', 'value': label, 'inline': false},
                  ],
                  'footer': {'text': 'Comic Vault'},
                  'timestamp': DateTime.now().toIso8601String(),
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  void _sendCorrectComicFollowUp(
      Map<String, dynamic> report, Comic correct) async {
    final correctLabel =
        '${correct.seriesName} #${correct.issueNumber ?? "?"} — ${correct.title}';
    try {
      await http
          .post(
            Uri.parse(_reportWebhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'embeds': [
                {
                  'title': '✅ User selected correct comic',
                  'color': 0x2ECC71,
                  'fields': [
                    {
                      'name': 'Barcode',
                      'value': report['barcode'] ?? '—',
                      'inline': true
                    },
                    {
                      'name': 'Was wrongly returned as',
                      'value': report['wrongComicLabel'] ?? '—',
                      'inline': false
                    },
                    {
                      'name': 'User chose',
                      'value': correctLabel,
                      'inline': false
                    },
                    if ((report['note'] as String?)?.isNotEmpty == true)
                      {
                        'name': 'User note',
                        'value': report['note'],
                        'inline': false
                      },
                  ],
                  'footer': {'text': 'Comic Vault'},
                  'timestamp': report['timestamp'],
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  void _pickSuggestion(_SeriesSuggestion s) {
    AppHaptics.select();
    _queryCtrl.text = s.searchQuery;
    _search(s.searchQuery);
  }

  void _selectFromHistory(String query) {
    AppHaptics.select();
    _queryCtrl.text = query;
    _search(query);
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
      body: Column(children: [
        _buildHeader(),
        if (_showSuggestions) _buildSuggestions(),
        if (widget.notFoundBarcode != null && _lastQuery.isEmpty)
          _buildNotFoundBanner(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          border: Border(
            bottom: BorderSide(
                color: AppColors.border.withOpacity(0.5), width: 1),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(children: [
              // Back button
              Pressable(
                onTap: () => Navigator.pop(context),
                haptic: HapticStyle.select,
                scaleDown: 0.88,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppColors.textSecondary, size: 16,
                      semanticLabel: 'Back'),
                ),
              ),
              const SizedBox(width: 12),

              // Search field
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.borderFocus),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: _loading
                          ? CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: AppColors.textTertiary.withOpacity(0.6),
                            )
                          : const Icon(Icons.search_rounded,
                              color: AppColors.textTertiary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _queryCtrl,
                        focusNode: _focusNode,
                        autofocus: widget.initialQuery.isEmpty,
                        style: tUi(15, weight: FontWeight.w400),
                        cursorColor: AppColors.textSecondary,
                        cursorWidth: 1.5,
                        decoration: InputDecoration(
                          hintText: 'Title, series, or barcode…',
                          hintStyle: tUi(15,
                              color: AppColors.textDisabled,
                              weight: FontWeight.w400),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search,
                      ),
                    ),
                    if (_queryCtrl.text.isNotEmpty)
                      Pressable(
                        onTap: () {
                          AppHaptics.light();
                          _debounce?.cancel();
                          _queryCtrl.clear();
                        },
                        haptic: HapticStyle.none,
                        scaleDown: 0.85,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.close_rounded,
                              color: AppColors.textTertiary, size: 16),
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),

              // Filter button with active dot
              Pressable(
                onTap: _openFilterSheet,
                haptic: HapticStyle.none,
                scaleDown: 0.88,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _hasActiveFilters
                            ? AppColors.surface3
                            : AppColors.surface2,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: _hasActiveFilters
                              ? AppColors.borderFocus
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(Icons.tune_rounded,
                          color: _hasActiveFilters
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          size: 18),
                    ),
                    if (_hasActiveFilters)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 8,
                          height: 8,
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
        ),
      );

  // ── Suggestions strip ─────────────────────────────────────────────────────

  Widget _buildSuggestions() => Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          border: Border(
            bottom: BorderSide(
                color: AppColors.border.withOpacity(0.4), width: 1),
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          scrollDirection: Axis.horizontal,
          physics: const BottomBouncingScrollPhysics(),
          itemCount: _suggestions.length,
          itemBuilder: (ctx, i) {
            final s = _suggestions[i];
            return Pressable(
              onTap: () => _pickSuggestion(s),
              haptic: HapticStyle.select,
              scaleDown: 0.94,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderFocus),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_stories_rounded,
                      color: AppColors.textTertiary.withOpacity(0.7),
                      size: 12),
                  const SizedBox(width: 6),
                  Text(s.displayLabel,
                      style: tUi(12,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w500)),
                ]),
              ),
            )
                .animate(delay: Duration(milliseconds: i * 45))
                .fadeIn(duration: 220.ms)
                .slideX(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
          },
        ),
      );

  // ── Body router ───────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();
    if (_results.isEmpty && _lastQuery.isNotEmpty) return _buildEmpty();
    if (_results.isEmpty) return _buildIdleHistory();
    return _buildResults();
  }

  // ── Barcode not found banner ──────────────────────────────────────────────

  Widget _buildNotFoundBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(Icons.qr_code_rounded, color: AppColors.textTertiary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Barcode not recognised',
                  style: tUi(13,
                      color: AppColors.textPrimary, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Search by title or series name to find the right comic.',
                  style: tUi(12,
                      color: AppColors.textSecondary,
                      weight: FontWeight.w400,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ]),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);

  // ── Idle — history list ───────────────────────────────────────────────────

  Widget _buildIdleHistory() {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.search_rounded,
                  color: AppColors.textDisabled, size: 32),
            ),
            const SizedBox(height: 24),
            Text('Search Comic Vine',
                style: tDisplay(20,
                    weight: FontWeight.w700, letterSpacing: -0.3)),
            const SizedBox(height: 10),
            Text(
              'Start typing to search titles,\nseries, or creators.',
              textAlign: TextAlign.center,
              style: tUi(13,
                  color: AppColors.textTertiary,
                  weight: FontWeight.w400,
                  height: 1.55),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),
      );
    }

    return CustomScrollView(
      physics: const BottomBouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: Row(children: [
              Text('RECENT SEARCHES',
                  style: tUi(10,
                      color: AppColors.textDisabled,
                      weight: FontWeight.w700,
                      letterSpacing: 1.6)),
              const Spacer(),
              Pressable(
                onTap: () async {
                  AppHaptics.medium();
                  await DatabaseService.instance.clearSearchHistory();
                  _loadSearchHistory();
                },
                haptic: HapticStyle.none,
                scaleDown: 0.9,
                child: Text('Clear all',
                    style: tUi(12,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w500)),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final h     = _searchHistory[i];
                final query = h['query'] as String;
                final count = h['resultCount'] as int;

                return Pressable(
                  onTap: () => _selectFromHistory(query),
                  haptic: HapticStyle.select,
                  scaleDown: 0.98,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.history_rounded,
                          color: AppColors.textDisabled, size: 17),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(query,
                            style: tUi(14,
                                color: AppColors.textSecondary,
                                weight: FontWeight.w500)),
                      ),
                      Text('$count results',
                          style: tUi(12,
                              color: AppColors.textDisabled,
                              weight: FontWeight.w400)),
                      const SizedBox(width: 8),
                      const Icon(Icons.north_west_rounded,
                          color: AppColors.textDisabled, size: 13),
                    ]),
                  ),
                )
                    .animate(
                        delay: Duration(milliseconds: i * 40))
                    .fadeIn(duration: 260.ms)
                    .slideY(
                        begin: 0.03,
                        end: 0,
                        curve: Curves.easeOutCubic);
              },
              childCount: _searchHistory.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 64)),
      ],
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoading() => CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => const _SkeletonResultCard()
                    .animate(
                      delay: Duration(milliseconds: i * 55),
                      onPlay: (c) => c.repeat(),
                    )
                    .shimmer(
                      duration: 1400.ms,
                      color:
                          AppColors.skeletonHighlight.withOpacity(0.3),
                    ),
                childCount: 5,
              ),
            ),
          ),
        ],
      );

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults() => CustomScrollView(
        physics: const BottomBouncingScrollPhysics(),
        slivers: [
          // Active filter pill
          if (_hasActiveFilters)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.tune_rounded,
                          size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Text(
                        [
                          if (_isRead == true) 'Read',
                          if (_isRead == false) 'Unread',
                          if (_minRating != null)
                            '${'★' * _minRating!}+ rating',
                          if (!_includeWishlist) 'No wishlist',
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
                            _includeWishlist = true;
                            _minRating       = null;
                            _isRead          = null;
                          });
                          if (_lastQuery.isNotEmpty) _search(_lastQuery);
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
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: RichText(
                text: TextSpan(
                  style: tUi(12,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w400),
                  children: [
                    const TextSpan(text: 'Showing '),
                    TextSpan(
                        text: '${_results.length}',
                        style: tUi(12,
                            color: AppColors.textSecondary,
                            weight: FontWeight.w700)),
                    const TextSpan(text: ' of '),
                    TextSpan(
                        text: '$_total',
                        style: tUi(12,
                            color: AppColors.textSecondary,
                            weight: FontWeight.w700)),
                    const TextSpan(text: ' for '),
                    TextSpan(
                        text: '"$_lastQuery"',
                        style: tUi(12,
                            color: AppColors.textTertiary,
                            weight: FontWeight.w500)),
                  ],
                ),
              ).animate().fadeIn(duration: 280.ms),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ResultCard(
                  comic: _results[i],
                  isOwned: _ownedIds.contains(_results[i].comicVineId),
                  isWishlisted:
                      _wishlistIds.contains(_results[i].comicVineId),
                  onTap: () => _openDetail(_results[i]),
                )
                    .animate(
                        delay: Duration(milliseconds: (i * 35).clamp(0, 400)))
                    .fadeIn(duration: 280.ms)
                    .slideY(
                        begin: 0.04,
                        end: 0,
                        curve: Curves.easeOutCubic),
                childCount: _results.length,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 64),
              child: _results.length < _total
                  ? Pressable(
                      onTap: _loadMore,
                      haptic: HapticStyle.light,
                      scaleDown: 0.97,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: _loadingMore
                              ? SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.textTertiary
                                        .withOpacity(0.6),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text('Load more',
                                        style: tUi(13,
                                            color: AppColors.textSecondary,
                                            weight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${_total - _results.length} remaining)',
                                      style: tUi(12,
                                          color: AppColors.textTertiary,
                                          weight: FontWeight.w400),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          _results.isEmpty ? '' : 'All $_total results shown',
                          style: tUi(12,
                              color: AppColors.textDisabled,
                              weight: FontWeight.w400),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      );

  // ── Empty / error ─────────────────────────────────────────────────────────

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: AppColors.textDisabled, size: 32),
            ),
            const SizedBox(height: 24),
            Text('Search failed',
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
              onTap: () => _search(_lastQuery),
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
          ]),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.search_off_rounded,
                  color: AppColors.textDisabled, size: 32),
            ),
            const SizedBox(height: 24),
            Text('No results found',
                style: tDisplay(20,
                    weight: FontWeight.w700, letterSpacing: -0.3)),
            const SizedBox(height: 10),
            Text(
              'Try a series name, issue title,\nor writer.',
              textAlign: TextAlign.center,
              style: tUi(13,
                  color: AppColors.textTertiary,
                  weight: FontWeight.w400,
                  height: 1.55),
            ),
          ]).animate().fadeIn(duration: 400.ms),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// RESULT CARD  — palette-tinted cover
// ══════════════════════════════════════════════════════════════════════════════

class _ResultCard extends StatefulWidget {
  final Comic comic;
  final bool isOwned;
  final bool isWishlisted;
  final VoidCallback onTap;

  const _ResultCard({
    required this.comic,
    required this.isOwned,
    required this.isWishlisted,
    required this.onTap,
  });

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  Color _palette = Colors.black;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(_ResultCard old) {
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
    final comic       = widget.comic;
    final borderColor = widget.isOwned
        ? AppColors.green_(0.25)
        : widget.isWishlisted
            ? AppColors.gold_(0.18)
            : AppColors.border;

    return Pressable(
      onTap: widget.onTap,
      haptic: HapticStyle.light,
      scaleDown: 0.97,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          // ── Cover with palette gradient ──────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(13)),
            child: SizedBox(
              width: 76,
              height: 114,
              child: Stack(fit: StackFit.expand, children: [
                comic.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: comic.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SkeletonBox.cover(),
                        errorWidget: (_, __, ___) =>
                            Container(color: AppColors.surface2),
                      )
                    : Container(
                        color: AppColors.surface2,
                        child: const Center(
                          child: Icon(Icons.menu_book_rounded,
                              color: AppColors.textDisabled, size: 28),
                        ),
                      ),
                // Palette-tinted right-edge fade blends into the card body
                Positioned(
                  top: 0, right: 0, bottom: 0,
                  width: 40,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          _palette.withOpacity(0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Text content ─────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comic.seriesName,
                    style: tUi(11,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comic.title.isNotEmpty
                        ? comic.title
                        : 'Issue #${comic.issueNumber ?? "?"}',
                    style: tUi(14,
                        color: AppColors.textPrimary,
                        weight: FontWeight.w700,
                        height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    if (comic.issueNumber != null)
                      _chip('#${comic.issueNumber}'),
                    if (comic.publicationYear != null)
                      _chip('${comic.publicationYear}'),
                    if (comic.publisher != null)
                      _chip(comic.publisher!, dim: true),
                  ]),
                ],
              ),
            ),
          ),

          // ── Status icon ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(
              widget.isOwned
                  ? Icons.check_circle_rounded
                  : widget.isWishlisted
                      ? Icons.bookmark_rounded
                      : Icons.chevron_right_rounded,
              color: widget.isOwned
                  ? AppColors.greenOwned
                  : widget.isWishlisted
                      ? AppColors.gold
                      : AppColors.textDisabled,
              size: widget.isOwned || widget.isWishlisted ? 20 : 16,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, {bool dim = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: tUi(10,
              color:
                  dim ? AppColors.textTertiary : AppColors.textSecondary,
              weight: FontWeight.w600),
        ),
      );
}

// ── Skeleton result card ──────────────────────────────────────────────────────

class _SkeletonResultCard extends StatelessWidget {
  const _SkeletonResultCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 114,
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
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(
                    height: 14,
                    width: 160,
                    decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(
                    height: 14,
                    width: 100,
                    decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(4))),
                const Spacer(),
                Row(children: [
                  Container(
                      height: 22,
                      width: 36,
                      decoration: BoxDecoration(
                          color: AppColors.skeletonBase,
                          borderRadius: BorderRadius.circular(5))),
                  const SizedBox(width: 6),
                  Container(
                      height: 22,
                      width: 36,
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