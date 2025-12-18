import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this._prefs) {
    _loadLocale();
  }
  static const String _key = 'locale';
  final SharedPreferences _prefs;
  Locale _locale = const Locale('en', 'US');

  Locale get locale => _locale;

  void _loadLocale() {
    final savedLocale = _prefs.getString(_key);
    if (savedLocale != null) {
      final parts = savedLocale.split('_');
      _locale = Locale(parts[0], parts.length > 1 ? parts[1] : '');
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    await _prefs.setString(
      _key,
      '${locale.languageCode}_${locale.countryCode}',
    );
    notifyListeners();
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'en') {
      setLocale(const Locale('hi', 'IN'));
    } else {
      setLocale(const Locale('en', 'US'));
    }
  }
}
