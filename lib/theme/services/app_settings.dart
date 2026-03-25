// lib/theme/services/app_settings.dart

import 'package:shared_preferences/shared_preferences.dart';

/// App-wide user preferences, loaded once at startup and synchronously
/// accessible everywhere via [AppSettings.instance].
class AppSettings {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  static const _keyCurrency          = 'currency_symbol';
  static const _keyHasSeenOnboarding = 'has_seen_onboarding';
  static const _keyLastSeenVersion   = 'last_seen_version';

  String _currencySymbol     = '\$';
  bool   _hasSeenOnboarding  = false;
  String _lastSeenVersion    = '';

  String get currencySymbol    => _currencySymbol;
  bool   get hasSeenOnboarding => _hasSeenOnboarding;
  String get lastSeenVersion   => _lastSeenVersion;

  /// Load persisted settings. Call once in main() before runApp().
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol    = prefs.getString(_keyCurrency)          ?? '\$';
    _hasSeenOnboarding = prefs.getBool(_keyHasSeenOnboarding)   ?? false;
    _lastSeenVersion   = prefs.getString(_keyLastSeenVersion)   ?? '';
  }

  Future<void> setCurrencySymbol(String symbol) async {
    final trimmed = symbol.trim();
    if (trimmed.isEmpty) return;
    _currencySymbol = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, trimmed);
  }

  Future<void> setHasSeenOnboarding() async {
    _hasSeenOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, true);
  }

  Future<void> setLastSeenVersion(String version) async {
    _lastSeenVersion = version;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSeenVersion, version);
  }
}
