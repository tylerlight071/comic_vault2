// lib/REST API/screens/onboarding_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/typography.dart';
import '../../theme/services/app_settings.dart';
import '../../widgets/pressable.dart';
import 'homescreen/home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.auto_stories_rounded,
      title: 'Welcome to\nComic Vault',
      body: 'Your personal comic library, beautifully kept. Track every issue, series, and read.',
      isWelcome: true,
    ),
    _OnboardingPage(
      icon: Icons.search_rounded,
      title: 'Search & Add\nAnything',
      body: 'Powered by Comic Vine — search millions of issues and add them to your collection instantly.',
    ),
    _OnboardingPage(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Scan to Add\nin Seconds',
      body: 'Point your camera at any comic barcode. Comic Vault identifies it and adds it for you.',
    ),
    _OnboardingPage(
      icon: Icons.bar_chart_rounded,
      title: 'Track, Organise\n& Explore',
      body: 'Log your reading, manage a wishlist, browse your stats, and follow your top series.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    await AppSettings.instance.setHasSeenOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [

        // ── Pages ──────────────────────────────────────────────────────────
        PageView.builder(
          controller: _controller,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => _PageContent(page: _pages[i], index: i),
        ),

        // ── Skip button ────────────────────────────────────────────────────
        if (!isLast)
          Positioned(
            top: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Pressable(
                  onTap: _skip,
                  scaleDown: 0.94,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('Skip',
                        style: tUi(13,
                            color: AppColors.textSecondary,
                            weight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),

        // ── Bottom controls ────────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 28),

                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    child: Pressable(
                      onTap: _next,
                      scaleDown: 0.97,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            isLast ? 'Get Started' : 'Next',
                            style: tUi(16,
                                color: AppColors.bg,
                                weight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;
  final bool isWelcome;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    this.isWelcome = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  final int index;

  const _PageContent({required this.page, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          const Spacer(flex: 3),

          // Icon / logo
          if (page.isWelcome)
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withOpacity(0.15),
                    blurRadius: 40,
                    spreadRadius: 4,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  duration: 450.ms,
                  curve: Curves.easeOutCubic,
                )
          else
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(page.icon, color: AppColors.textPrimary, size: 40),
            )
                .animate()
                .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  duration: 450.ms,
                  curve: Curves.easeOutCubic,
                ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: AppColors.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.15,
            ),
          )
              .animate(delay: 80.ms)
              .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
              .slideY(begin: 0.08, end: 0, duration: 380.ms, curve: Curves.easeOutCubic),

          const SizedBox(height: 18),

          // Body
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.6,
              letterSpacing: 0.1,
            ),
          )
              .animate(delay: 150.ms)
              .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic),

          const Spacer(flex: 4),
        ],
      ),
    );
  }
}
