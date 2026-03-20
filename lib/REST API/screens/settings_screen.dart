// lib/REST API/screens/settings_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/models/home_layout.dart';
import '../../theme/models/comic.dart';
import '../../theme/models/shelf_config.dart';
import '../../theme/typography.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';
import '../../theme/app_colors.dart';
import '../../theme/services/database_service.dart';
import '../../theme/utils/haptics.dart';
import '../../../widgets/pressable.dart';

// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  final HomeLayout currentLayout;
  final void Function(HomeLayout) onLayoutChanged;
  final VoidCallback onDataChanged;

  const SettingsScreen({
    super.key,
    required this.currentLayout,
    required this.onLayoutChanged,
    required this.onDataChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool   _refreshing   = false;
  int    _refreshDone  = 0;
  int    _refreshTotal = 0;
  bool   _exporting    = false;
  bool   _importing    = false;
  late   HomeLayout _layout;
  String _appVersion   = '';

  ShelfConfig _shelves = const ShelfConfig();

  final _apiKeyCtrl = TextEditingController();
  bool  _apiKeyObscured = true;

  @override
  void initState() {
    super.initState();
    _layout = widget.currentLayout;
    _loadVersion();
    _loadPersistedSettings();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedSettings() async {
    final prefs   = await SharedPreferences.getInstance();
    final shelves = await ShelfConfig.load();
    final apiKey  = prefs.getString('comic_vine_api_key') ?? '';
    if (mounted) {
      setState(() {
        _shelves = shelves;
        _apiKeyCtrl.text = apiKey;
      });
    }
  }

  Future<void> _saveApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('comic_vine_api_key', value.trim());
  }

  Future<void> _toggleShelf(String key, bool value) async {
    final updated = _shelves.copyWith(
      showCurrentlyReading: key == 'currently_reading' ? value : null,
      showRecentlyAdded:    key == 'recently_added'    ? value : null,
      showContinueReading:  key == 'continue_reading'  ? value : null,
      showTopRated:         key == 'top_rated'         ? value : null,
    );
    setState(() => _shelves = updated);
    await updated.save();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _startRefresh() async {
    final ok = await _confirmDialog(
      title: 'Refresh Vault Data',
      message:
          'Re-fetches covers, series info, credits and descriptions for every comic. Your read status, ratings and barcodes are kept.',
      confirmLabel: 'Refresh',
      confirmColor: AppColors.textPrimary,
    );
    if (ok != true) return;
    setState(() { _refreshing = true; _refreshDone = 0; _refreshTotal = 0; });
    await DatabaseService.instance.refreshAllComics(
      onProgress: (done, total) {
        if (mounted) setState(() { _refreshDone = done; _refreshTotal = total; });
      },
    );
    if (mounted) {
      setState(() => _refreshing = false);
      widget.onDataChanged();
      AppHaptics.success();
      _snack('Vault refreshed', icon: Icons.check_circle_rounded);
    }
  }

  Future<void> _clearAllData() async {
    final ok = await _confirmDialog(
      title: 'Clear All Data',
      message:
          'Permanently deletes every comic in your library and wishlist. This cannot be undone.',
      confirmLabel: 'Delete Everything',
      confirmColor: AppColors.redDestructive,
    );
    if (ok != true) return;
    AppHaptics.heavy();
    await DatabaseService.instance.deleteAllComics();
    widget.onDataChanged();
    if (mounted) _snack('All data cleared');
  }

  Future<void> _clearSearchHistory() async {
    AppHaptics.medium();
    await DatabaseService.instance.clearSearchHistory();
    if (mounted) _snack('Search history cleared');
  }

  Future<void> _clearBarcodeHistory() async {
    AppHaptics.medium();
    await DatabaseService.instance.clearBarcodeHistory();
    if (mounted) _snack('Scan history cleared');
  }

  Future<void> _exportData() async {
    if (_exporting) return;
    AppHaptics.medium();
    setState(() => _exporting = true);
    try {
      final library  = await DatabaseService.instance.getAllComics();
      final wishlist = await DatabaseService.instance.getWishlist();
      final all = [...library, ...wishlist];
      final payload = const JsonEncoder.withIndent('  ')
          .convert(all.map((c) => c.toMap()).toList());
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/comic_vault_backup.json');
      await file.writeAsString(payload);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Comic Vault Backup',
      );
    } catch (e) {
      if (mounted) _snack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importData() async {
    if (_importing) return;
    AppHaptics.medium();
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Import from JSON', style: tUi(17, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste the contents of a Comic Vault backup file below. Existing comics with the same ID will be skipped.',
              style: tUi(13, color: AppColors.textSecondary, weight: FontWeight.w400, height: 1.55),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 6,
              style: tUi(12, color: AppColors.textPrimary, weight: FontWeight.w400, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Paste JSON here…',
                hintStyle: tUi(12, color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: tUi(14, color: AppColors.textSecondary, weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Import', style: tUi(14, color: AppColors.textPrimary, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _importing = true);
    try {
      final list = jsonDecode(ctrl.text) as List<dynamic>;
      int imported = 0;
      for (final item in list) {
        try {
          final map = Map<String, dynamic>.from(item as Map);
          map.remove('id'); // let DB assign a new id
          final comic = Comic.fromMap({...map, 'addedDate': map['addedDate'] ?? DateTime.now().toIso8601String()});
          final exists = await DatabaseService.instance.comicExists(comic.comicVineId);
          if (!exists) {
            await DatabaseService.instance.insertComic(comic);
            imported++;
          }
        } catch (_) {}
      }
      widget.onDataChanged();
      if (mounted) _snack('Imported $imported comic${imported == 1 ? '' : 's'}', icon: Icons.check_circle_rounded);
    } catch (_) {
      if (mounted) _snack('Invalid JSON — check the file and try again.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: tUi(17, weight: FontWeight.w700)),
          content: Text(message,
              style: tUi(14,
                  color: AppColors.textSecondary,
                  weight: FontWeight.w400,
                  height: 1.55)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: tUi(14,
                      color: AppColors.textSecondary,
                      weight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel,
                  style: tUi(14,
                      color: confirmColor, weight: FontWeight.w700)),
            ),
          ],
        ),
      );

  void _snack(String msg, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
        ],
        Text(msg, style: tUi(13, color: AppColors.textPrimary)),
      ]),
      backgroundColor: AppColors.snackbar,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Branded header ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 28, 2, 32),
                    child: Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.menu_book_rounded,
                            color: AppColors.bg, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ComicVault',
                              style: tDisplay(20,
                                  weight: FontWeight.w700,
                                  letterSpacing: -0.4)),
                          Text(
                              _appVersion.isEmpty
                                  ? '—'
                                  : 'Version $_appVersion',
                              style: tUi(12,
                                  color: AppColors.textTertiary,
                                  weight: FontWeight.w400)),
                        ],
                      ),
                    ]),
                  ),

                  // ── Home Layout ─────────────────────────────────────────
                  _sectionLabel('HOME LAYOUT'),
                  const SizedBox(height: 10),
                  _layoutPicker(),

                  const SizedBox(height: 28),

                  // ── Shelves ──────────────────────────────────────────────
                  _sectionLabel('HOME SHELVES'),
                  const SizedBox(height: 10),
                  _shelvesConfig(),

                  const SizedBox(height: 28),

                  // ── API ──────────────────────────────────────────────────
                  _sectionLabel('API'),
                  const SizedBox(height: 10),
                  _apiKeyTile(),

                  const SizedBox(height: 28),

                  // ── Data ────────────────────────────────────────────────
                  _sectionLabel('DATA'),
                  const SizedBox(height: 10),
                  _refreshTile(),
                  const SizedBox(height: 1),
                  _actionTile(
                    icon: Icons.history_rounded,
                    iconBg: AppColors.surface2,
                    iconColor: AppColors.textSecondary,
                    label: 'Clear Search History',
                    description: 'Remove all past search queries.',
                    onTap: _clearSearchHistory,
                    isFirst: false,
                    isLast: false,
                  ),
                  const SizedBox(height: 1),
                  _actionTile(
                    icon: Icons.qr_code_scanner_rounded,
                    iconBg: AppColors.surface2,
                    iconColor: AppColors.textSecondary,
                    label: 'Clear Scan History',
                    description: 'Remove all past barcode scans.',
                    onTap: _clearBarcodeHistory,
                    isFirst: false,
                    isLast: false,
                  ),
                  const SizedBox(height: 1),
                  const SizedBox(height: 1),
                  _actionTile(
                    icon: Icons.upload_rounded,
                    iconBg: AppColors.accentDim,
                    iconColor: AppColors.accent,
                    label: _exporting ? 'Exporting…' : 'Export Library',
                    description: 'Save a JSON backup of your full collection.',
                    onTap: _exportData,
                    isFirst: false,
                    isLast: false,
                  ),
                  const SizedBox(height: 1),
                  _actionTile(
                    icon: Icons.download_rounded,
                    iconBg: AppColors.greenOwnedDim,
                    iconColor: AppColors.greenOwned,
                    label: _importing ? 'Importing…' : 'Import Library',
                    description: 'Restore from a JSON backup file.',
                    onTap: _importData,
                    isFirst: false,
                    isLast: false,
                  ),
                  const SizedBox(height: 1),
                  _actionTile(
                    icon: Icons.delete_forever_rounded,
                    iconBg: AppColors.redDestructive.withOpacity(0.08),
                    iconColor: AppColors.redDestructive,
                    borderColor: AppColors.red_(0.2),
                    label: 'Clear All Data',
                    labelColor: AppColors.redDestructive,
                    description:
                        'Permanently delete your library and wishlist.',
                    onTap: _clearAllData,
                    isFirst: false,
                    isLast: true,
                  ),

                  const SizedBox(height: 28),

                  // ── About ────────────────────────────────────────────────
                  _sectionLabel('ABOUT'),
                  const SizedBox(height: 10),
                  _infoGroup([
                    _InfoRow(label: 'Metadata', value: 'Comic Vine API'),
                    _InfoRow(
                        label: 'Storage',
                        value: 'Local SQLite · no cloud'),
                    _InfoRow(label: 'Ads', value: 'None. Ever.'),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shelves config ────────────────────────────────────────────────────────

  Widget _shelvesConfig() {
    final items = [
      ('Currently Reading', 'currently_reading', _shelves.showCurrentlyReading),
      ('Recently Added',    'recently_added',    _shelves.showRecentlyAdded),
      ('Continue Reading',  'continue_reading',  _shelves.showContinueReading),
      ('Top Rated',         'top_rated',         _shelves.showTopRated),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i     = e.key;
          final label = e.value.$1;
          final key   = e.value.$2;
          final value = e.value.$3;
          final last  = i == items.length - 1;
          return Container(
            decoration: BoxDecoration(
              border: last ? null : Border(
                bottom: BorderSide(color: AppColors.border.withOpacity(0.4)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Text(label,
                      style: tUi(14,
                          color: AppColors.textPrimary,
                          weight: FontWeight.w500)),
                ),
                Switch(
                  value: value,
                  onChanged: (v) {
                    AppHaptics.select();
                    _toggleShelf(key, v);
                  },
                  activeColor: AppColors.greenOwned,
                  trackOutlineColor: WidgetStateProperty.all(
                      AppColors.border),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── API key tile ──────────────────────────────────────────────────────────

  Widget _apiKeyTile() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comic Vine API Key',
                style: tUi(14,
                    color: AppColors.textPrimary,
                    weight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(
              'Optionally use your own key from comicvine.gamespot.com. '
              'Leave blank to use the built-in key.',
              style: tUi(12,
                  color: AppColors.textTertiary,
                  weight: FontWeight.w400,
                  height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _apiKeyCtrl,
                    obscureText: _apiKeyObscured,
                    onChanged: _saveApiKey,
                    style: tUi(13,
                        color: AppColors.textPrimary,
                        weight: FontWeight.w400),
                    decoration: InputDecoration(
                      hintText: 'Paste API key here…',
                      hintStyle: tUi(13,
                          color: AppColors.textDisabled,
                          weight: FontWeight.w400),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Pressable(
                  onTap: () => setState(
                      () => _apiKeyObscured = !_apiKeyObscured),
                  haptic: HapticStyle.light,
                  scaleDown: 0.88,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Icon(
                      _apiKeyObscured
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.textTertiary,
                      size: 18,
                    ),
                  ),
                ),
              ]),
            ),
            if (_apiKeyCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Pressable(
                onTap: () async {
                  _apiKeyCtrl.clear();
                  await _saveApiKey('');
                  setState(() {});
                  if (mounted) _snack('API key cleared');
                },
                haptic: HapticStyle.light,
                scaleDown: 0.95,
                child: Text('Clear custom key',
                    style: tUi(12,
                        color: AppColors.redDestructive.withOpacity(0.75),
                        weight: FontWeight.w500)),
              ),
            ],
          ],
        ),
      );

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
            Text('PREFERENCES',
                style: tUi(10,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const SizedBox(height: 2),
            Text('Settings',
                style: tDisplay(17,
                    weight: FontWeight.w700, letterSpacing: -0.4)),
          ],
        ),
      );

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(text,
            style: tUi(10,
                color: AppColors.textTertiary,
                weight: FontWeight.w700,
                letterSpacing: 1.6)),
      );

  // ── Layout picker ─────────────────────────────────────────────────────────

  Widget _layoutPicker() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Home screen style',
                style: tUi(14,
                    color: AppColors.textPrimary,
                    weight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('Choose how your collection is displayed on launch.',
                style: tUi(12,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w400,
                    height: 1.4)),
            const SizedBox(height: 16),
            Row(children: [
              _layoutOption(
                HomeLayout.featured,
                Icons.featured_play_list_rounded,
                'Featured',
                'Spotlight + shelves',
              ),
              const SizedBox(width: 8),
              _layoutOption(
                HomeLayout.shelves,
                Icons.view_agenda_rounded,
                'Shelves',
                'Horizontal rows',
              ),
              const SizedBox(width: 8),
              _layoutOption(
                HomeLayout.mosaic,
                Icons.grid_view_rounded,
                'Mosaic',
                'Cover grid',
              ),
            ]),
          ],
        ),
      );

  Widget _layoutOption(
      HomeLayout value, IconData icon, String label, String sub) {
    final selected = _layout == value;
    return Expanded(
      child: Pressable(
        onTap: () {
          setState(() => _layout = value);
          widget.onLayoutChanged(value);
          AppHaptics.select();
        },
        haptic: HapticStyle.none,
        scaleDown: 0.94,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.textPrimary : AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.border,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color: selected
                    ? AppColors.bg
                    : AppColors.textSecondary,
                size: 20),
            const SizedBox(height: 6),
            Text(label,
                style: tUi(12,
                    color: selected
                        ? AppColors.bg
                        : AppColors.textPrimary,
                    weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(sub,
                textAlign: TextAlign.center,
                style: tUi(9,
                    color: selected
                        ? AppColors.bg.withOpacity(0.55)
                        : AppColors.textDisabled,
                    weight: FontWeight.w400,
                    height: 1.3)),
          ]),
        ),
      ),
    );
  }

  // ── Refresh tile ──────────────────────────────────────────────────────────

  Widget _refreshTile() => Pressable(
        onTap: _refreshing ? null : _startRefresh,
        haptic: HapticStyle.none,
        scaleDown: _refreshing ? 1.0 : 0.98,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.sync_rounded,
                      color: AppColors.textSecondary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Refresh Vault Data',
                          style: tUi(14,
                              color: AppColors.textPrimary,
                              weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Re-fetch metadata for all comics.',
                          style: tUi(12,
                              color: AppColors.textTertiary,
                              weight: FontWeight.w400,
                              height: 1.4)),
                    ],
                  ),
                ),
                if (!_refreshing)
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textDisabled, size: 18),
              ]),
              if (_refreshing) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _refreshTotal > 0
                        ? _refreshDone / _refreshTotal
                        : null,
                    backgroundColor: AppColors.surface2,
                    valueColor: const AlwaysStoppedAnimation(
                        AppColors.accent),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _refreshTotal > 0
                      ? 'Updating $_refreshDone of $_refreshTotal comics…'
                      : 'Starting refresh…',
                  style: tUi(12,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w400),
                ),
              ],
            ],
          ),
        ),
      );

  // ── Generic action tile ───────────────────────────────────────────────────

  Widget _actionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String description,
    required VoidCallback onTap,
    Color? labelColor,
    Color? borderColor,
    bool isFirst = false,
    bool isLast = false,
  }) {
    BorderRadius radius = BorderRadius.zero;
    if (isFirst && isLast) radius = BorderRadius.circular(14);
    else if (isFirst) radius = const BorderRadius.vertical(top: Radius.circular(14));
    else if (isLast)  radius = const BorderRadius.vertical(bottom: Radius.circular(14));

    return Pressable(
      onTap: onTap,
      haptic: HapticStyle.none,
      scaleDown: 0.98,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: radius,
          border: Border.all(
              color: borderColor ?? AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: borderColor?.withOpacity(0.4) ??
                      AppColors.border),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: tUi(14,
                        color: labelColor ?? AppColors.textPrimary,
                        weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description,
                    style: tUi(12,
                        color: AppColors.textTertiary,
                        weight: FontWeight.w400,
                        height: 1.4)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textDisabled, size: 18),
        ]),
      ),
    );
  }

  // ── About info group ──────────────────────────────────────────────────────

  Widget _infoGroup(List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final i    = e.key;
          final row  = e.value;
          final last = i == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: last
                  ? null
                  : Border(
                      bottom: BorderSide(
                          color: AppColors.border.withOpacity(0.4))),
            ),
            child: Row(children: [
              Text(row.label,
                  style: tUi(13,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w500)),
              const Spacer(),
              Text(row.value,
                  style: tUi(13,
                      color: AppColors.textSecondary,
                      weight: FontWeight.w500)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Info row model ────────────────────────────────────────────────────────────

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
}