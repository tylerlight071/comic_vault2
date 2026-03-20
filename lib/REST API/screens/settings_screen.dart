// lib/REST API/screens/settings_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/bottom_bouncing_scroll_physics.dart';
import '../../theme/app_colors.dart';
import '../../theme/services/database_service.dart';
import '../../theme/utils/haptics.dart';
import '../../../widgets/pressable.dart';

// ── Typography ────────────────────────────────────────────────────────────────

TextStyle _display(double size,
        {Color? color,
        FontWeight weight = FontWeight.w700,
        double? height,
        double letterSpacing = -0.5}) =>
    GoogleFonts.playfairDisplay(
      color: color ?? AppColors.textPrimary,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );

TextStyle _ui(double size,
        {Color? color,
        FontWeight weight = FontWeight.w500,
        double? height,
        double letterSpacing = 0}) =>
    GoogleFonts.dmSans(
      color: color ?? AppColors.textPrimary,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );

// ─────────────────────────────────────────────────────────────────────────────

enum HomeLayout { featured, shelves, mosaic }

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
  bool _refreshing  = false;
  int  _refreshDone = 0;
  int  _refreshTotal = 0;
  late HomeLayout _layout;

  @override
  void initState() {
    super.initState();
    _layout = widget.currentLayout;
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
          title: Text(title, style: _ui(17, weight: FontWeight.w700)),
          content: Text(message,
              style: _ui(14,
                  color: AppColors.textSecondary,
                  weight: FontWeight.w400,
                  height: 1.55)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: _ui(14,
                      color: AppColors.textSecondary,
                      weight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel,
                  style: _ui(14,
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
        Text(msg, style: _ui(13, color: AppColors.textPrimary)),
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
                              style: _display(20,
                                  weight: FontWeight.w700,
                                  letterSpacing: -0.4)),
                          Text('Version 1.9.4',
                              style: _ui(12,
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
                  color: AppColors.textSecondary, size: 16),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PREFERENCES',
                style: _ui(10,
                    color: AppColors.textTertiary,
                    weight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const SizedBox(height: 2),
            Text('Settings',
                style: _display(17,
                    weight: FontWeight.w700, letterSpacing: -0.4)),
          ],
        ),
      );

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(text,
            style: _ui(10,
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
                style: _ui(14,
                    color: AppColors.textPrimary,
                    weight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('Choose how your collection is displayed on launch.',
                style: _ui(12,
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
                style: _ui(12,
                    color: selected
                        ? AppColors.bg
                        : AppColors.textPrimary,
                    weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(sub,
                textAlign: TextAlign.center,
                style: _ui(9,
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
                          style: _ui(14,
                              color: AppColors.textPrimary,
                              weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Re-fetch metadata for all comics.',
                          style: _ui(12,
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
                        AppColors.textPrimary),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _refreshTotal > 0
                      ? 'Updating $_refreshDone of $_refreshTotal comics…'
                      : 'Starting refresh…',
                  style: _ui(12,
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
                    style: _ui(14,
                        color: labelColor ?? AppColors.textPrimary,
                        weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description,
                    style: _ui(12,
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
                  style: _ui(13,
                      color: AppColors.textTertiary,
                      weight: FontWeight.w500)),
              const Spacer(),
              Text(row.value,
                  style: _ui(13,
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