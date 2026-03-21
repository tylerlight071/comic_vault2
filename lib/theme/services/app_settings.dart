// lib/theme/services/app_settings.dart

import 'package:shared_preferences/shared_preferences.dart';

/// App-wide user preferences, loaded once at startup and synchronously
/// accessible everywhere via [AppSettings.instance].
class AppSettings {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  static const _keyCurrency = 'currency_symbol';

  String _currencySymbol = '\$';

  /// The user's chosen currency symbol (e.g. '$', '€', '£').
  String get currencySymbol => _currencySymbol;

  /// Load persisted settings. Call once in main() before runApp().
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol = prefs.getString(_keyCurrency) ?? '\$';
  }

  /// Persist a new currency symbol and update the in-memory value.
  Future<void> setCurrencySymbol(String symbol) async {
    final trimmed = symbol.trim();
    if (trimmed.isEmpty) return;
    _currencySymbol = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, trimmed);
  }
}
