// lib/theme/services/cover_palette_service.dart

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';

/// Extracts and caches a darkened dominant colour from a comic cover image.
///
/// Two-level cache:
///   L1 — in-memory map (instantaneous, lives for the app session)
///   L2 — SharedPreferences (survives restarts, so extraction only ever runs
///         once per unique URL across the lifetime of the app)
///
/// In-flight deduplication: if N widgets request the same URL before the first
/// extraction completes, they all await the same Future rather than spawning N
/// concurrent PaletteGenerator calls.
class CoverPaletteService {
  static final CoverPaletteService instance = CoverPaletteService._();
  CoverPaletteService._();

  static const String _prefsPrefix = 'cv_p_';
  // Cap in-memory entries. When exceeded the oldest quarter is evicted.
  static const int _maxCacheSize = 200;

  // L1 — in-memory
  final Map<String, Color> _cache = {};

  // In-flight deduplication — URL → Future that is currently running
  final Map<String, Future<Color>> _pending = {};

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Call once at app startup (after [WidgetsFlutterBinding.ensureInitialized]).
  /// No-op — kept for API compatibility. L2 is checked lazily in [getColor].
  Future<void> init() async {}

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the dominant colour for [imageUrl], or [AppColors.bg] on failure.
  ///
  /// Never fires more than one extraction per URL at a time — concurrent callers
  /// for the same URL await the same underlying Future.
  Future<Color> getColor(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return AppColors.bg;

    // L1 hit
    final cached = _cache[imageUrl];
    if (cached != null) return cached;

    // L2 hit — check SharedPreferences before hitting the network
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt('$_prefsPrefix${_hashUrl(imageUrl)}');
      if (stored != null) {
        final color = Color(stored);
        _cache[imageUrl] = color;
        return color;
      }
    } catch (_) {}

    // In-flight dedup — join existing extraction if one is running
    final inFlight = _pending[imageUrl];
    if (inFlight != null) return inFlight;

    // Start a new extraction and register it so others can join
    final future = _extract(imageUrl);
    _pending[imageUrl] = future;

    try {
      return await future;
    } finally {
      _pending.remove(imageUrl);
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<Color> _extract(String imageUrl) async {
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        // 56×84 is sufficient for colour sampling and ~4× faster to decode
        // than the previous 112×168.
        size: const Size(56, 84),
        maximumColorCount: 6,
      );

      final raw = generator.darkVibrantColor?.color
          ?? generator.vibrantColor?.color
          ?? generator.darkMutedColor?.color
          ?? generator.dominantColor?.color
          ?? AppColors.bg;

      final processed = _processColor(raw);

      // Store in L1 — evict oldest quarter when the cap is hit
      if (_cache.length >= _maxCacheSize) {
        final evict = _cache.keys.take(_maxCacheSize ~/ 4).toList();
        for (final k in evict) _cache.remove(k);
      }
      _cache[imageUrl] = processed;

      // Persist to L2 asynchronously — don't await, never block the caller
      _persist(imageUrl, processed);

      return processed;
    } catch (_) {
      // Network error, decode error, unsupported format — fall back silently.
      return AppColors.bg;
    }
  }

  Future<void> _persist(String imageUrl, Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefsPrefix${_hashUrl(imageUrl)}', color.toARGB32());
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }

  /// Stable djb2 hash of the URL — keeps prefs keys short and consistent
  /// across runs (unlike Dart's built-in hashCode which is randomised).
  String _hashUrl(String url) {
    var h = 5381;
    for (final c in url.codeUnits) {
      h = ((h << 5) + h + c) & 0x1FFFFFFF;
    }
    return h.toRadixString(36);
  }

  /// Clamps lightness so the colour is always visibly tinted but never bright
  /// enough to wash out white text. Nudges saturation so muted covers still
  /// produce a perceptible ambient glow.
  Color _processColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness(hsl.lightness.clamp(0.07, 0.24))
        .withSaturation((hsl.saturation + 0.12).clamp(0.0, 1.0))
        .toColor();
  }
}