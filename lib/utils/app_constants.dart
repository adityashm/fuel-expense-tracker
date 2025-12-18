class AppConstants {
  // Validation limits
  static const double minAmount = 0.01;
  static const double maxAmount = 999999.99;
  static const int maxDescriptionLength = 500;
  static const int maxOdometerValue = 9999999;
  static const int maxLiters = 9999;

  // Pagination
  static const int paginationBatchSize = 20;

  // UI Timing
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration loadingDelay = Duration(milliseconds: 500);

  // Spacing (8px grid system)
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;

  // Border radius
  static const double borderRadius8 = 8.0;
  static const double borderRadius12 = 12.0;
  static const double borderRadius16 = 16.0;

  // Card elevation
  static const double cardElevation = 2.0;
  static const double cardElevationHover = 4.0;

  // Network
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  static const Duration connectionTimeout = Duration(seconds: 30);

  // Cache
  static const Duration cacheDuration = Duration(minutes: 5);

  // Image
  static const int imageQuality = 85;
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1920;
}
