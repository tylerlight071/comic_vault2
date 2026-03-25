// lib/REST API/screens/splash_screen.dart

// ignore_for_file: unnecessary_import, deprecated_member_use

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import '../../theme/typography.dart';
import '../../theme/services/app_settings.dart';
import '../../theme/services/update_service.dart';
import 'homescreen/home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  // Start the update check in parallel with the splash animation.
  final Future<UpdateInfo?> _updateFuture = UpdateService.check();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    Future.delayed(const Duration(milliseconds: 1600), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    // ── First launch → onboarding ────────────────────────────────────────
    if (!AppSettings.instance.hasSeenOnboarding) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
      return;
    }

    // ── Wait for update check (already in-flight, capped at 3s total) ───
    final update = await _updateFuture.timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );

    if (!mounted) return;

    // ── Force update — block the app ─────────────────────────────────────
    if (update != null && update.forceUpdate) {
      await _showForceUpdateDialog(update);
      return; // user cannot proceed without updating
    }

    // ── Optional update ───────────────────────────────────────────────────
    if (update != null && update.hasUpdate) {
      await _showUpdateDialog(update);
      if (!mounted) return;
    }

    // ── What's New (version changed since last launch) ────────────────────
    if (update != null &&
        !update.hasUpdate &&
        update.currentVersion != AppSettings.instance.lastSeenVersion) {
      await _showWhatsNewDialog(update);
      await AppSettings.instance.setLastSeenVersion(update.currentVersion);
      if (!mounted) return;
    }

    // ── Navigate to home ──────────────────────────────────────────────────
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ── Force update dialog (cannot be dismissed) ──────────────────────────────

  Future<void> _showForceUpdateDialog(UpdateInfo update) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: AppColors.accent, size: 26),
              ),
              const SizedBox(height: 16),
              Text('Update Required',
                  style: tUi(18, weight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version ${update.remoteVersion} is required to continue. Please download and install the latest APK from GitHub.',
                style: tUi(14,
                    color: AppColors.textSecondary,
                    weight: FontWeight.w400,
                    height: 1.55),
                textAlign: TextAlign.center,
              ),
              if (update.changelog.isNotEmpty) ...[
                const SizedBox(height: 20),
                _ChangelogList(changelog: update.changelog),
              ],
              const SizedBox(height: 20),
              SelectableText(
                'github.com/tylerlight071/comic_vault2/releases',
                style: tUi(12,
                    color: AppColors.accent,
                    weight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Optional update dialog ─────────────────────────────────────────────────

  Future<void> _showUpdateDialog(UpdateInfo update) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accentDim,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: AppColors.accent, size: 26),
            ),
            const SizedBox(height: 16),
            Text('Update Available',
                style: tUi(18, weight: FontWeight.w700),
                textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Version ${update.remoteVersion} is available. Download and install the latest APK from GitHub.',
              style: tUi(14,
                  color: AppColors.textSecondary,
                  weight: FontWeight.w400,
                  height: 1.55),
              textAlign: TextAlign.center,
            ),
            if (update.changelog.isNotEmpty) ...[
              const SizedBox(height: 20),
              _ChangelogList(changelog: update.changelog),
            ],
            const SizedBox(height: 20),
            SelectableText(
              'github.com/tylerlight071/comic_vault2/releases',
              style: tUi(12,
                  color: AppColors.accent,
                  weight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Later',
                style: tUi(14,
                    color: AppColors.textSecondary,
                    weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── What's New dialog ──────────────────────────────────────────────────────

  Future<void> _showWhatsNewDialog(UpdateInfo update) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.goldDim,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.gold, size: 26),
            ),
            const SizedBox(height: 16),
            Text("What's New in ${update.currentVersion}",
                style: tUi(18, weight: FontWeight.w700),
                textAlign: TextAlign.center),
          ],
        ),
        content: _ChangelogList(changelog: update.changelog),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Nice!',
                style: tUi(14,
                    color: AppColors.textPrimary,
                    weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(fit: StackFit.expand, children: [

        // ── Panel grid ──────────────────────────────────────────────────
        Positioned.fill(
          child: CustomPaint(painter: _PanelGridPainter())
              .animate()
              .fadeIn(duration: 900.ms, curve: Curves.easeIn),
        ),

        // ── Top vignette ────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          height: size.height * 0.3,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.bg, AppColors.bg.withOpacity(0)],
              ),
            ),
          ),
        ),

        // ── Bottom vignette ─────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: size.height * 0.3,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.bg, AppColors.bg.withOpacity(0)],
              ),
            ),
          ),
        ),

        // ── Radial glow ─────────────────────────────────────────────────
        Positioned(
          top: size.height * 0.26,
          left: 0, right: 0,
          child: Center(
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.textPrimary.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 700.ms),
        ),

        // ── Centre lockup ───────────────────────────────────────────────
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // App logo
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.18),
                      blurRadius: 40,
                      spreadRadius: 4,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic)
                  .scale(
                    begin: const Offset(0.78, 0.78),
                    end: const Offset(1.0, 1.0),
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 26),

              Text(
                'Comic Vault',
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1.05,
                ),
              )
                  .animate(delay: 180.ms)
                  .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

              const SizedBox(height: 8),

              Text(
                'Your collection, beautifully kept.',
                style: GoogleFonts.dmSans(
                  color: AppColors.textTertiary.withOpacity(0.75),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              )
                  .animate(delay: 320.ms)
                  .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic),
            ],
          ),
        ),

        // ── Bottom loading strip ─────────────────────────────────────────
        Positioned(
          bottom: 48, left: 0, right: 0,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 100),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.surface2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textPrimary.withOpacity(0.45),
                  ),
                  minHeight: 2,
                ),
              ),
            )
                .animate(delay: 650.ms)
                .fadeIn(duration: 380.ms),

            const SizedBox(height: 16),

            Text(
              'Powered by Comic Vine',
              style: GoogleFonts.dmSans(
                color: AppColors.textDisabled.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            )
                .animate(delay: 720.ms)
                .fadeIn(duration: 380.ms),
          ]),
        ),
      ]),
    );
  }
}

// ── Changelog list widget ──────────────────────────────────────────────────────

class _ChangelogList extends StatelessWidget {
  final List<String> changelog;
  const _ChangelogList({required this.changelog});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: changelog.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Text(item,
                    style: tUi(13,
                        color: AppColors.textSecondary,
                        weight: FontWeight.w400,
                        height: 1.5)),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

// ── Panel grid painter ────────────────────────────────────────────────────────

class _PanelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final panels = [
      const Rect.fromLTWH(20, 56, 118, 154),
      const Rect.fromLTWH(148, 56, 82, 74),
      const Rect.fromLTWH(148, 140, 82, 70),
      Rect.fromLTWH(size.width - 112, 36, 94, 136),
      Rect.fromLTWH(size.width - 112, 182, 94, 58),
      Rect.fromLTWH(16, size.height - 224, 98, 82),
      Rect.fromLTWH(16, size.height - 132, 98, 112),
      Rect.fromLTWH(124, size.height - 182, 68, 162),
      Rect.fromLTWH(size.width - 92, size.height - 204, 74, 92),
      Rect.fromLTWH(size.width - 92, size.height - 102, 74, 82),
      Rect.fromLTWH(0, size.height * 0.42, 14, size.height * 0.16),
      Rect.fromLTWH(size.width - 14, size.height * 0.44, 14, size.height * 0.14),
    ];

    for (final rect in panels) {
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rr, paint);
    }
  }

  @override
  bool shouldRepaint(_PanelGridPainter oldDelegate) => false;
}
