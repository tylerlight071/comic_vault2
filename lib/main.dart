// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_colors.dart';
import 'theme/services/database_service.dart';
import 'theme/services/cover_palette_service.dart';
import 'theme/services/app_settings.dart';
import 'REST API/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialise services in parallel — DB and palette cache are independent
  await Future.wait([
    DatabaseService.instance.init(),
    CoverPaletteService.instance.init(),
    AppSettings.instance.init(),
  ]);

  runApp(const ComicVaultApp());
}

class ComicVaultApp extends StatelessWidget {
  const ComicVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comic Vault',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      scrollBehavior: const _ClampingScrollBehavior(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface1,
        primary: AppColors.textPrimary,
        secondary: AppColors.gold,
        error: AppColors.redDestructive,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgElevated,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.dmSans(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.snackbar,
        contentTextStyle: GoogleFonts.dmSans(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Clamps overscroll on all platforms and removes the default glow indicator.
class _ClampingScrollBehavior extends MaterialScrollBehavior {
  const _ClampingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}