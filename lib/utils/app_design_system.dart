import 'package:flutter/material.dart';

/// Modern Design System for Fuel Expense Tracker
/// Clean, Premium, and Accessible

class AppColors {
  // Primary Palette - Modern Indigo
  static const Color primary = Color(0xFF6366F1);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFE0E7FF);
  static const Color onPrimaryContainer = Color(0xFF3730A3);

  // Secondary Palette - Emerald Green
  static const Color secondary = Color(0xFF10B981);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD1FAE5);
  static const Color onSecondaryContainer = Color(0xFF065F46);

  // Tertiary Palette - Amber
  static const Color tertiary = Color(0xFFF59E0B);
  static const Color onTertiary = Color(0xFF000000);
  static const Color tertiaryContainer = Color(0xFFFEF3C7);
  static const Color onTertiaryContainer = Color(0xFFB45309);

  // Error Palette
  static const Color error = Color(0xFFEF4444);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFFB91C1C);

  // Expense Type Colors - Vibrant & Distinguishable
  static const Color fuelExpense = Color(0xFFF59E0B); // Amber
  static const Color generalExpense = Color(0xFF3B82F6); // Blue
  static const Color householdExpense = Color(0xFF10B981); // Emerald
  static const Color chargingExpense = Color(0xFF8B5CF6); // Purple

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue

  // Household Balance Colors
  static const Color owedMoney = Color(0xFF10B981); // Green (paid more)
  static const Color owesMoney = Color(0xFFEF4444); // Red (owes)
  static const Color settled = Color(0xFF94A3B8); // Grey (balanced)

  // Surface Colors - Light
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF1E293B);
  static const Color onSurfaceVariantLight = Color(0xFF64748B);
  static const Color outlineLight = Color(0xFFE2E8F0);

  // Surface Colors - Dark
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color onSurfaceDark = Color(0xFFF1F5F9);
  static const Color onSurfaceVariantDark = Color(0xFF94A3B8);
  static const Color outlineDark = Color(0xFF334155);

  // Category Colors (for visual coding)
  static const Map<String, Color> categoryColors = {
    'Groceries': Color(0xFF10B981),
    'Utilities': Color(0xFF3B82F6),
    'Healthcare': Color(0xFFEC4899),
    'Education': Color(0xFF8B5CF6),
    'Entertainment': Color(0xFFF59E0B),
    'Shopping': Color(0xFFEC4899),
    'Food': Color(0xFFF97316),
    'Transport': Color(0xFF06B6D4),
    'Other': Color(0xFF94A3B8),
    'Fuel': Color(0xFFF59E0B),
    'Maintenance': Color(0xFF78716C),
    'Insurance': Color(0xFF6366F1),
    'Parking': Color(0xFF64748B),
    'Charging': Color(0xFF8B5CF6),
  };

  // Gradients for cards
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fuelGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient householdGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient vehicleGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Get category color with fallback
  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? const Color(0xFF94A3B8);
  }

  // Get gradient for expense type
  static LinearGradient getExpenseGradient(String type) {
    switch (type.toLowerCase()) {
      case 'fuel':
        return fuelGradient;
      case 'household':
        return householdGradient;
      case 'vehicle':
      case 'general':
        return vehicleGradient;
      default:
        return primaryGradient;
    }
  }
}

class AppSpacing {
  /// 4dp Grid System
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing14 = 14.0;
  static const double spacing16 = 16.0;
  static const double spacing18 = 18.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing28 = 28.0;
  static const double spacing32 = 32.0;
  static const double spacing36 = 36.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  static const double spacing56 = 56.0;
  static const double spacing64 = 64.0;

  // Touch targets
  static const double minTouchTarget = 44.0; // iOS minimum
  static const double touchTarget = 48.0; // Material minimum
  static const double largeTouchTarget = 56.0; // Primary action buttons

  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.all(16);
  static const EdgeInsets screenPaddingHorizontal =
      EdgeInsets.symmetric(horizontal: 16);
}

class AppBorderRadius {
  static const double none = 0.0;
  static const double xs = 4.0;
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xLarge = 20.0;
  static const double xxLarge = 24.0;
  static const double xxxLarge = 32.0;
  static const double circular = 999.0;

  // Prebuilt BorderRadius objects
  static BorderRadius get smallRadius => BorderRadius.circular(small);
  static BorderRadius get mediumRadius => BorderRadius.circular(medium);
  static BorderRadius get largeRadius => BorderRadius.circular(large);
  static BorderRadius get xLargeRadius => BorderRadius.circular(xLarge);
  static BorderRadius get xxLargeRadius => BorderRadius.circular(xxLarge);
  static BorderRadius get circularRadius => BorderRadius.circular(circular);
}

class AppElevation {
  static const double level0 = 0.0;
  static const double level1 = 1.0;
  static const double level2 = 2.0;
  static const double level3 = 4.0;
  static const double level4 = 6.0;
  static const double level5 = 8.0;
}

/// Icon sizes
class AppIconSize {
  static const double xs = 16.0;
  static const double small = 20.0;
  static const double medium = 24.0;
  static const double large = 28.0;
  static const double xLarge = 32.0;
  static const double xxLarge = 40.0;
  static const double xxxLarge = 48.0;
}

/// Animation durations
class AppDuration {
  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration slower = Duration(milliseconds: 500);
}
