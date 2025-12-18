import 'package:intl/intl.dart';

/// Formatting utility class
/// Provides consistent formatting across the app
class Formatters {
  // Currency formatters
  static final NumberFormat _currencyINR = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
    locale: 'en_IN',
  );

  static final NumberFormat _currencyUSD = NumberFormat.currency(
    symbol: r'$',
    decimalDigits: 2,
  );

  // Date formatters
  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _monthYear = DateFormat('MMM yyyy');
  static final DateFormat _fullDate = DateFormat('EEEE, dd MMMM yyyy');
  static final DateFormat _shortDate = DateFormat('dd/MM/yyyy');

  // Number formatters
  static final NumberFormat _decimal = NumberFormat('#,##0.00');
  static final NumberFormat _integer = NumberFormat('#,##0');
  static final NumberFormat _percentage = NumberFormat('#,##0.0%');

  /// Format currency amount (INR)
  static String currency(double amount, {String? symbol}) {
    if (symbol == r'$') {
      return _currencyUSD.format(amount);
    }
    return _currencyINR.format(amount);
  }

  /// Format currency without symbol
  static String currencyNoSymbol(double amount) {
    return _decimal.format(amount);
  }

  /// Format date (dd MMM yyyy)
  static String date(DateTime date) => _date.format(date);

  /// Format date and time (dd MMM yyyy, hh:mm a)
  static String dateTime(DateTime dateTime) => _dateTime.format(dateTime);

  /// Format time only (hh:mm a)
  static String time(DateTime dateTime) => _time.format(dateTime);

  /// Format month and year (MMM yyyy)
  static String monthYear(DateTime date) => _monthYear.format(date);

  /// Format full date (Wednesday, 15 December 2025)
  static String fullDate(DateTime date) => _fullDate.format(date);

  /// Format short date (15/12/2025)
  static String shortDate(DateTime date) => _shortDate.format(date);

  /// Format decimal number
  static String decimal(double value, {int decimals = 2}) {
    return NumberFormat('#,##0.${'0' * decimals}').format(value);
  }

  /// Format integer
  static String integer(int value) => _integer.format(value);

  /// Format percentage (0.25 -> 25.0%)
  static String percentage(double value) => _percentage.format(value);

  /// Format distance (km)
  static String distance(double km) {
    if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Format fuel volume (liters)
  static String fuelVolume(double liters) {
    return '${liters.toStringAsFixed(2)} L';
  }

  /// Format fuel efficiency (km/L)
  static String fuelEfficiency(double kmPerLiter) {
    return '${kmPerLiter.toStringAsFixed(2)} km/L';
  }

  /// Format cost per liter
  static String costPerLiter(double cost) {
    return '${cost.toStringAsFixed(2)}/L';
  }

  /// Format duration (minutes to readable format)
  static String duration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '$hours hr';
    }
    return '$hours hr $mins min';
  }

  /// Format file size (bytes to readable format)
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format relative time (e.g., "2 hours ago", "Yesterday")
  static String relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  /// Format phone number (add country code if missing)
  static String phone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.length == 10) return '+91$cleaned'; // India
    return cleaned;
  }

  /// Format vehicle registration (add spaces)
  static String vehicleRegistration(String registration) {
    final cleaned = registration.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (cleaned.length >= 10) {
      // Format: DL 01 AB 1234
      return '${cleaned.substring(0, 2)} ${cleaned.substring(2, 4)} ${cleaned.substring(4, 6)} ${cleaned.substring(6)}';
    }
    return registration.toUpperCase();
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Format large numbers with K, M, B suffix
  static String compactNumber(double number) {
    if (number < 1000) return number.toStringAsFixed(0);
    if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)}K';
    if (number < 1000000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    return '${(number / 1000000000).toStringAsFixed(1)}B';
  }
}
