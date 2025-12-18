import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Haptic feedback helper
class HapticHelper {
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  static void vibrate() {
    HapticFeedback.vibrate();
  }

  /// Haptic for successful action
  static void success() {
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 50), () {
      HapticFeedback.lightImpact();
    });
  }

  /// Haptic for error action
  static void error() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.mediumImpact();
    });
  }

  /// Haptic for button tap
  static void buttonTap() {
    HapticFeedback.lightImpact();
  }

  /// Haptic for navigation
  static void navigation() {
    HapticFeedback.selectionClick();
  }
}

/// Extension on Widget to add haptic feedback easily
extension HapticWidget on Widget {
  Widget withHaptic(
      {VoidCallback? onTap,
      HapticFeedbackType type = HapticFeedbackType.light,}) {
    return GestureDetector(
      onTap: () {
        switch (type) {
          case HapticFeedbackType.light:
            HapticHelper.lightImpact();
            break;
          case HapticFeedbackType.medium:
            HapticHelper.mediumImpact();
            break;
          case HapticFeedbackType.heavy:
            HapticHelper.heavyImpact();
            break;
          case HapticFeedbackType.selection:
            HapticHelper.selectionClick();
            break;
        }
        onTap?.call();
      },
      child: this,
    );
  }
}

enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}
