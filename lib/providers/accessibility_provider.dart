import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityProvider extends ChangeNotifier {
  AccessibilityProvider(this._prefs)
      : _highContrast = _prefs.getBool(_highContrastKey) ?? false,
        _textScale = _prefs.getDouble(_textScaleKey) ?? 1.0,
        _reduceMotion = _prefs.getBool(_reduceMotionKey) ?? false;
  static const _highContrastKey = 'accessibility_high_contrast';
  static const _textScaleKey = 'accessibility_text_scale';
  static const _reduceMotionKey = 'accessibility_reduce_motion';

  final SharedPreferences _prefs;
  bool _highContrast;
  double _textScale;
  bool _reduceMotion;

  bool get highContrast => _highContrast;
  double get textScale => _textScale;
  bool get reduceMotion => _reduceMotion;

  void setHighContrast(bool value) {
    if (_highContrast == value) return;
    _highContrast = value;
    _prefs.setBool(_highContrastKey, value);
    notifyListeners();
  }

  void setTextScale(double value) {
    final clamped = value.clamp(0.8, 1.6);
    if (_textScale == clamped) return;
    _textScale = clamped;
    _prefs.setDouble(_textScaleKey, clamped);
    notifyListeners();
  }

  void setReduceMotion(bool value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    _prefs.setBool(_reduceMotionKey, value);
    notifyListeners();
  }
}
