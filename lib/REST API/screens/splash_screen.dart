// lib/REST API/screens/splash_screen.dart

// ignore_for_file: unnecessary_import, deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import 'homescreen/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    Future.delayed(const Duration(milliseconds: 2400), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

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
                colors: [
                  AppColors.bg,
                  AppColors.bg.withOpacity(0),
                ],
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
                colors: [
                  AppColors.bg,
                  AppColors.bg.withOpacity(0),
                ],
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

              // Icon mark — solid filled, matches app logo style
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
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
                child: Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.bg,
                  size: 34,
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

              // App name
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

              // Tagline
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

// ── Panel grid painter ────────────────────────────────────────────────────────

class _PanelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final panels = [
      // Top-left cluster
      const Rect.fromLTWH(20, 56, 118, 154),
      const Rect.fromLTWH(148, 56, 82, 74),
      const Rect.fromLTWH(148, 140, 82, 70),

      // Top-right
      Rect.fromLTWH(size.width - 112, 36, 94, 136),
      Rect.fromLTWH(size.width - 112, 182, 94, 58),

      // Bottom-left
      Rect.fromLTWH(16, size.height - 224, 98, 82),
      Rect.fromLTWH(16, size.height - 132, 98, 112),
      Rect.fromLTWH(124, size.height - 182, 68, 162),

      // Bottom-right
      Rect.fromLTWH(size.width - 92, size.height - 204, 74, 92),
      Rect.fromLTWH(size.width - 92, size.height - 102, 74, 82),

      // Mid-left accent (single narrow panel)
      Rect.fromLTWH(0, size.height * 0.42, 14, size.height * 0.16),

      // Mid-right accent
      Rect.fromLTWH(size.width - 14, size.height * 0.44,
          14, size.height * 0.14),
    ];

    for (final rect in panels) {
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rr, paint);
    }
  }

  @override
  bool shouldRepaint(_PanelGridPainter oldDelegate) => false;
}