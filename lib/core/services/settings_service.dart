import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_locale_controller.dart'; // To reuse AppLanguage

class SettingsService extends ChangeNotifier {
  static const _themeKey = 'app_theme_mode';
  static const _langKey = 'app_language_code';
  static const _animationQualityKey = 'animation_quality';
  static const _pushNotificationsKey = 'push_notifications';
  static const _emailDigestKey = 'email_digest';
  static const _twoFactorAuthKey = 'two_factor_auth';
  static const _dataCollectionKey = 'data_collection';
  static const _biometricLoginKey = 'biometric_login';
  static const _timeZoneKey = 'time_zone';

  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.english;
  bool _animationQuality = true;
  bool _pushNotifications = true;
  bool _emailDigest = false;
  bool _twoFactorAuth = false;
  bool _dataCollection = false;
  bool _biometricLogin = false;
  String _timeZone = 'UTC+03:00';

  bool _isLoaded = false;
  late SharedPreferences _prefs;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  bool get animationQuality => _animationQuality;
  bool get pushNotifications => _pushNotifications;
  bool get emailDigest => _emailDigest;
  bool get twoFactorAuth => _twoFactorAuth;
  bool get dataCollection => _dataCollection;
  bool get biometricLogin => _biometricLogin;
  String get timeZone => _timeZone;
  bool get isLoaded => _isLoaded;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load Theme
    final themeIndex = _prefs.getInt(_themeKey);
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }

    // Load Language
    final langCode = _prefs.getString(_langKey);
    if (langCode != null) {
      _language = AppLanguage.fromCode(langCode);
    }

    _animationQuality = _prefs.getBool(_animationQualityKey) ?? true;
    _pushNotifications = _prefs.getBool(_pushNotificationsKey) ?? true;
    _emailDigest = _prefs.getBool(_emailDigestKey) ?? false;
    _twoFactorAuth = _prefs.getBool(_twoFactorAuthKey) ?? false;
    _dataCollection = _prefs.getBool(_dataCollectionKey) ?? false;
    _biometricLogin = _prefs.getBool(_biometricLoginKey) ?? false;
    _timeZone = _prefs.getString(_timeZoneKey) ?? 'UTC+03:00';

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

  Future<void> updateAnimationQuality(bool enabled) =>
      _updateBool(_animationQualityKey, enabled, (value) {
        _animationQuality = value;
      });

  Future<void> updatePushNotifications(bool enabled) =>
      _updateBool(_pushNotificationsKey, enabled, (value) {
        _pushNotifications = value;
      });

  Future<void> updateEmailDigest(bool enabled) =>
      _updateBool(_emailDigestKey, enabled, (value) {
        _emailDigest = value;
      });

  Future<void> updateTwoFactorAuth(bool enabled) =>
      _updateBool(_twoFactorAuthKey, enabled, (value) {
        _twoFactorAuth = value;
      });

  Future<void> updateDataCollection(bool enabled) =>
      _updateBool(_dataCollectionKey, enabled, (value) {
        _dataCollection = value;
      });

  Future<void> updateBiometricLogin(bool enabled) =>
      _updateBool(_biometricLoginKey, enabled, (value) {
        _biometricLogin = value;
      });

  Future<void> updateTimeZone(String timeZone) async {
    if (timeZone == _timeZone) return;
    _timeZone = timeZone;
    await _prefs.setString(_timeZoneKey, timeZone);
    notifyListeners();
  }

  Future<void> _updateBool(
    String key,
    bool enabled,
    void Function(bool value) updateLocal,
  ) async {
    updateLocal(enabled);
    await _prefs.setBool(key, enabled);
    notifyListeners();
  }
}
