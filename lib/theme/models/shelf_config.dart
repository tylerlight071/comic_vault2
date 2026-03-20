// lib/theme/models/shelf_config.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Which home-screen shelves the user wants to see.
///
/// Persisted via SharedPreferences; all shelves are visible by default.
class ShelfConfig {
  final bool showCurrentlyReading;
  final bool showRecentlyAdded;
  final bool showContinueReading;
  final bool showTopRated;

  const ShelfConfig({
    this.showCurrentlyReading = true,
    this.showRecentlyAdded    = true,
    this.showContinueReading  = true,
    this.showTopRated         = true,
  });

  static Future<ShelfConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ShelfConfig(
      showCurrentlyReading: prefs.getBool('shelf_currently_reading') ?? true,
      showRecentlyAdded:    prefs.getBool('shelf_recently_added')    ?? true,
      showContinueReading:  prefs.getBool('shelf_continue_reading')  ?? true,
      showTopRated:         prefs.getBool('shelf_top_rated')         ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shelf_currently_reading', showCurrentlyReading);
    await prefs.setBool('shelf_recently_added',    showRecentlyAdded);
    await prefs.setBool('shelf_continue_reading',  showContinueReading);
    await prefs.setBool('shelf_top_rated',         showTopRated);
  }

  ShelfConfig copyWith({
    bool? showCurrentlyReading,
    bool? showRecentlyAdded,
    bool? showContinueReading,
    bool? showTopRated,
  }) =>
      ShelfConfig(
        showCurrentlyReading: showCurrentlyReading ?? this.showCurrentlyReading,
        showRecentlyAdded:    showRecentlyAdded    ?? this.showRecentlyAdded,
        showContinueReading:  showContinueReading  ?? this.showContinueReading,
        showTopRated:         showTopRated         ?? this.showTopRated,
      );
}
