import 'package:flutter/material.dart';
import 'v25_design_system.dart';

/// V2.5 Theme Configuration with Dark Mode (AMOLED) support
class V25ThemeConfig {
  /// Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: V25DesignSystem.primaryBlue,
      scaffoldBackgroundColor: V25DesignSystem.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: V25DesignSystem.primaryBlue,
        secondary: V25DesignSystem.primaryBlueDark,
        surface: V25DesignSystem.surfaceLight,
        error: V25DesignSystem.error,
        onSecondary: Colors.white,
        onSurface: V25DesignSystem.neutral900,
      ),
      textTheme: V25DesignSystem.getTextTheme(),
      cardTheme: CardThemeData(
        color: V25DesignSystem.backgroundLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: V25DesignSystem.primaryButtonStyle,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: V25DesignSystem.secondaryButtonStyle,
      ),
      textButtonTheme: TextButtonThemeData(
        style: V25DesignSystem.textButtonStyle,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: V25DesignSystem.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
          borderSide: const BorderSide(color: V25DesignSystem.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
          borderSide:
              const BorderSide(color: V25DesignSystem.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
          borderSide: const BorderSide(color: V25DesignSystem.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: V25DesignSystem.spacing16,
          vertical: V25DesignSystem.spacing16,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: V25DesignSystem.neutral100,
        labelStyle: V25DesignSystem.getTextTheme().bodyMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: V25DesignSystem.spacing12,
          vertical: V25DesignSystem.spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusSmall),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: V25DesignSystem.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: V25DesignSystem.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle:
            V25DesignSystem.getTextTheme(isDark: true).headlineMedium,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: V25DesignSystem.backgroundLight,
        selectedItemColor: V25DesignSystem.primaryBlue,
        unselectedItemColor: V25DesignSystem.neutral500,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: V25DesignSystem.neutral200,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: V25DesignSystem.backgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusLarge),
        ),
      ),
    );
  }

  /// Dark Theme (AMOLED)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: V25DesignSystem.primaryBlueLight,
      scaffoldBackgroundColor:
          V25DesignSystem.backgroundDark, // Pure black for AMOLED
      colorScheme: const ColorScheme.dark(
        primary: V25DesignSystem.primaryBlueLight,
        secondary: V25DesignSystem.primaryBlue,
        surface: V25DesignSystem.surfaceDark,
        error: V25DesignSystem.error,
        onPrimary: V25DesignSystem.neutral900,
        onSecondary: Colors.white,
        onError: Colors.white,
      ),
      textTheme: V25DesignSystem.getTextTheme(isDark: true),
      cardTheme: CardThemeData(
        color: V25DesignSystem.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: V25DesignSystem.primaryButtonStyle.copyWith(
          backgroundColor:
              WidgetStateProperty.all(V25DesignSystem.primaryBlueLight),
          foregroundColor: WidgetStateProperty.all(V25DesignSystem.neutral900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: V25DesignSystem.secondaryButtonStyle.copyWith(
          foregroundColor:
              WidgetStateProperty.all(V25DesignSystem.primaryBlueLight),
          side: WidgetStateProperty.all(
            const BorderSide(color: V25DesignSystem.primaryBlueLight, width: 2),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: V25DesignSystem.textButtonStyle.copyWith(
          foregroundColor:
              WidgetStateProperty.all(V25DesignSystem.primaryBlueLight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: V25DesignSystem.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
          borderSide: const BorderSide(color: V25DesignSystem.neutral700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
          borderSide: const BorderSide(
              color: V25DesignSystem.primaryBlueLight, width: 2,),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
          borderSide: const BorderSide(color: V25DesignSystem.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: V25DesignSystem.spacing16,
          vertical: V25DesignSystem.spacing16,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: V25DesignSystem.neutral800,
        labelStyle: V25DesignSystem.getTextTheme(isDark: true).bodyMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: V25DesignSystem.spacing12,
          vertical: V25DesignSystem.spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusSmall),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: V25DesignSystem.primaryBlueLight,
        foregroundColor: V25DesignSystem.neutral900,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: V25DesignSystem.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle:
            V25DesignSystem.getTextTheme(isDark: true).headlineMedium,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: V25DesignSystem.surfaceDark,
        selectedItemColor: V25DesignSystem.primaryBlueLight,
        unselectedItemColor: V25DesignSystem.neutral500,
        type: BottomNavigationBarType.fixed,
        elevation: 0, // Flat for AMOLED
      ),
      dividerTheme: const DividerThemeData(
        color: V25DesignSystem.neutral800,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: V25DesignSystem.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V25DesignSystem.radiusLarge),
        ),
      ),
    );
  }

  /// High Contrast Light Theme (Accessibility)
  static ThemeData get highContrastLightTheme {
    return lightTheme.copyWith(
      colorScheme: ColorScheme.light(
        primary: Colors.blue.shade900,
        secondary: Colors.blue.shade800,
        error: Colors.red.shade900,
        onSecondary: Colors.white,
      ),
      textTheme: V25DesignSystem.getTextTheme().apply(
        fontSizeFactor: 1.1,
      ),
    );
  }

  /// High Contrast Dark Theme (Accessibility)
  static ThemeData get highContrastDarkTheme {
    return darkTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: ColorScheme.dark(
        primary: Colors.blue.shade200,
        secondary: Colors.blue.shade300,
        surface: Colors.grey.shade900,
        error: Colors.red.shade300,
      ),
      textTheme: V25DesignSystem.getTextTheme(isDark: true).apply(
        fontSizeFactor: 1.1,
      ),
    );
  }

  /// Apply accessibility modifications
  static ThemeData applyAccessibility(
    ThemeData theme, {
    bool highContrast = false,
    bool largeText = false,
  }) {
    var modifiedTheme = theme;

    if (highContrast) {
      modifiedTheme = theme.brightness == Brightness.light
          ? highContrastLightTheme
          : highContrastDarkTheme;
    }

    if (largeText) {
      modifiedTheme = modifiedTheme.copyWith(
        textTheme: modifiedTheme.textTheme.apply(fontSizeFactor: 1.2),
      );
    }

    return modifiedTheme;
  }
}
