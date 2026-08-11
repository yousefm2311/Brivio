import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_locale_controller.dart'; // To reuse AppLanguage

class SettingsService extends ChangeNotifier {
  static const _themeKey = 'app_theme_mode';
  static const _langKey = 'app_language_code';

  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.english;
  
  bool _isLoaded = false;
  late SharedPreferences _prefs;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  bool get isLoaded => _isLoaded;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load Theme
    final themeIndex = _prefs.getInt(_themeKey);
    if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }

    // Load Language
    final langCode = _prefs.getString(_langKey);
    if (langCode != null) {
      _language = AppLanguage.fromCode(langCode);
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode newThemeMode) async {
    if (newThemeMode == _themeMode) return;
    _themeMode = newThemeMode;
    await _prefs.setInt(_themeKey, newThemeMode.index);
    notifyListeners();
  }

  Future<void> updateLanguage(AppLanguage newLanguage) async {
    if (newLanguage == _language) return;
    _language = newLanguage;
    await _prefs.setString(_langKey, newLanguage.code);
    notifyListeners();
  }
}
