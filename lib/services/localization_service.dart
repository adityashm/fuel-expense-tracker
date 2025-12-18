import 'package:flutter/material.dart';

/// Localization service for multi-language support
class LocalizationService {
  LocalizationService._internal();

  factory LocalizationService() {
    return _instance;
  }
  static final LocalizationService _instance = LocalizationService._internal();

  Locale _currentLocale = const Locale('en', 'US');

  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English
    Locale('hi', 'IN'), // Hindi
    Locale('ta', 'IN'), // Tamil
    Locale('te', 'IN'), // Telugu
    Locale('mr', 'IN'), // Marathi
    Locale('bn', 'IN'), // Bengali
    Locale('gu', 'IN'), // Gujarati
    Locale('kn', 'IN'), // Kannada
  ];

  // Translation maps
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // Common
      'app_name': 'Fuel & Expense Tracker',
      'home': 'Home',
      'expenses': 'Expenses',
      'analytics': 'Analytics',
      'settings': 'Settings',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'search': 'Search',
      'filter': 'Filter',
      'date': 'Date',
      'amount': 'Amount',
      'category': 'Category',
      'description': 'Description',
      'total': 'Total',

      // Expenses
      'add_expense': 'Add Expense',
      'fuel_expense': 'Fuel Expense',
      'general_expense': 'General Expense',
      'household_expense': 'Household Expense',
      'expense_details': 'Expense Details',
      'no_expenses': 'No expenses yet',
      'expense_added': 'Expense added successfully',
      'expense_updated': 'Expense updated successfully',
      'expense_deleted': 'Expense deleted successfully',

      // Categories
      'groceries': 'Groceries',
      'utilities': 'Utilities',
      'transportation': 'Transportation',
      'healthcare': 'Healthcare',
      'entertainment': 'Entertainment',
      'dining': 'Dining',
      'shopping': 'Shopping',
      'education': 'Education',
      'rent': 'Rent',
      'insurance': 'Insurance',

      // Analytics
      'total_expenses': 'Total Expenses',
      'this_month': 'This Month',
      'last_month': 'Last Month',
      'spending_trends': 'Spending Trends',
      'category_breakdown': 'Category Breakdown',
      'insights': 'Insights',
      'predictions': 'Predictions',

      // Notifications
      'payment_reminder': 'Payment Reminder',
      'budget_alert': 'Budget Alert',
      'recurring_expense_due': 'Recurring Expense Due',
      'daily_summary': 'Daily Summary',

      // Settings
      'language': 'Language',
      'theme': 'Theme',
      'notifications': 'Notifications',
      'export': 'Export',
      'about': 'About',
    },
    'hi': {
      // Common
      'app_name': 'ईंधन और व्यय ट्रैकर',
      'home': 'होम',
      'expenses': 'खर्चे',
      'analytics': 'विश्लेषण',
      'settings': 'सेटिंग्स',
      'save': 'सहेजें',
      'cancel': 'रद्द करें',
      'delete': 'हटाएं',
      'edit': 'संपादित करें',
      'add': 'जोड़ें',
      'search': 'खोजें',
      'filter': 'फ़िल्टर',
      'date': 'तारीख',
      'amount': 'रकम',
      'category': 'श्रेणी',
      'description': 'विवरण',
      'total': 'कुल',

      // Expenses
      'add_expense': 'खर्च जोड़ें',
      'fuel_expense': 'ईंधन खर्च',
      'general_expense': 'सामान्य खर्च',
      'household_expense': 'घरेलू खर्च',
      'expense_details': 'खर्च का विवरण',
      'no_expenses': 'अभी तक कोई खर्च नहीं',
      'expense_added': 'खर्च सफलतापूर्वक जोड़ा गया',
      'expense_updated': 'खर्च अपडेट किया गया',
      'expense_deleted': 'खर्च हटाया गया',

      // Categories
      'groceries': 'किराने का सामान',
      'utilities': 'उपयोगिताएँ',
      'transportation': 'परिवहन',
      'healthcare': 'स्वास्थ्य देखभाल',
      'entertainment': 'मनोरंजन',
      'dining': 'भोजन',
      'shopping': 'खरीदारी',
      'education': 'शिक्षा',
      'rent': 'किराया',
      'insurance': 'बीमा',

      // Analytics
      'total_expenses': 'कुल खर्च',
      'this_month': 'इस महीने',
      'last_month': 'पिछले महीने',
      'spending_trends': 'खर्च के रुझान',
      'category_breakdown': 'श्रेणी विभाजन',
      'insights': 'अंतर्दृष्टि',
      'predictions': 'पूर्वानुमान',

      // Notifications
      'payment_reminder': 'भुगतान अनुस्मारक',
      'budget_alert': 'बजट चेतावनी',
      'recurring_expense_due': 'आवर्ती खर्च देय',
      'daily_summary': 'दैनिक सारांश',

      // Settings
      'language': 'भाषा',
      'theme': 'थीम',
      'notifications': 'सूचनाएं',
      'export': 'निर्यात',
      'about': 'के बारे में',
    },
    'ta': {
      // Common
      'app_name': 'எரிபொருள் மற்றும் செலவு கண்காணிப்பாளர்',
      'home': 'முகப்பு',
      'expenses': 'செலவுகள்',
      'analytics': 'பகுப்பாய்வு',
      'settings': 'அமைப்புகள்',
      'save': 'சேமி',
      'cancel': 'ரத்து',
      'delete': 'நீக்கு',
      'edit': 'திருத்து',
      'add': 'சேர்',
      'search': 'தேடு',
      'filter': 'வடிகட்டி',
      'date': 'தேதி',
      'amount': 'தொகை',
      'category': 'வகை',
      'description': 'விவரம்',
      'total': 'மொத்தம்',

      // Expenses
      'add_expense': 'செலவு சேர்',
      'fuel_expense': 'எரிபொருள் செலவு',
      'general_expense': 'பொது செலவு',
      'household_expense': 'வீட்டு செலவு',
      'expense_details': 'செலவு விவரங்கள்',
      'no_expenses': 'இன்னும் செலவுகள் இல்லை',
      'expense_added': 'செலவு வெற்றிகரமாக சேர்க்கப்பட்டது',
      'expense_updated': 'செலவு புதுப்பிக்கப்பட்டது',
      'expense_deleted': 'செலவு நீக்கப்பட்டது',

      // Categories
      'groceries': 'மளிகை',
      'utilities': 'பயன்பாடுகள்',
      'transportation': 'போக்குவரத்து',
      'healthcare': 'சுகாதாரம்',
      'entertainment': 'பொழுதுபோக்கு',
      'dining': 'உணவு',
      'shopping': 'ஷாப்பிங்',
      'education': 'கல்வி',
      'rent': 'வாடகை',
      'insurance': 'காப்பீடு',
    },
    'te': {
      // Common
      'app_name': 'ఇంధనం మరియు వ్యయ ట్రాకర్',
      'home': 'హోమ్',
      'expenses': 'ఖర్చులు',
      'analytics': 'విశ్లేషణలు',
      'settings': 'సెట్టింగులు',
      'save': 'సేవ్',
      'cancel': 'రద్దు',
      'delete': 'తొలగించు',
      'edit': 'సవరించు',
      'add': 'జోడించు',
      'search': 'వెతకండి',
      'filter': 'ఫిల్టర్',
      'date': 'తేదీ',
      'amount': 'మొత్తం',
      'category': 'వర్గం',
      'description': 'వివరణ',
      'total': 'మొత్తం',

      // Expenses
      'add_expense': 'ఖర్చు జోడించండి',
      'fuel_expense': 'ఇంధన ఖర్చు',
      'general_expense': 'సాధారణ ఖర్చు',
      'household_expense': 'గృహ ఖర్చు',
      'expense_details': 'ఖర్చు వివరాలు',
      'no_expenses': 'ఇంకా ఖర్చులు లేవు',
      'expense_added': 'ఖర్చు విజయవంతంగా జోడించబడింది',
      'expense_updated': 'ఖర్చు నవీకరించబడింది',
      'expense_deleted': 'ఖర్చు తొలగించబడింది',
    },
    'mr': {
      // Common
      'app_name': 'इंधन आणि खर्च ट्रॅकर',
      'home': 'मुख्यपृष्ठ',
      'expenses': 'खर्च',
      'analytics': 'विश्लेषण',
      'settings': 'सेटिंग्ज',
      'save': 'जतन करा',
      'cancel': 'रद्द करा',
      'delete': 'हटवा',
      'edit': 'संपादित करा',
      'add': 'जोडा',
      'search': 'शोधा',
      'filter': 'फिल्टर',
      'date': 'तारीख',
      'amount': 'रक्कम',
      'category': 'श्रेणी',
      'description': 'वर्णन',
      'total': 'एकूण',
    },
    'bn': {
      // Common
      'app_name': 'জ্বালানি এবং ব্যয় ট্র্যাকার',
      'home': 'হোম',
      'expenses': 'খরচ',
      'analytics': 'বিশ্লেষণ',
      'settings': 'সেটিংস',
      'save': 'সংরক্ষণ',
      'cancel': 'বাতিল',
      'delete': 'মুছুন',
      'edit': 'সম্পাদনা',
      'add': 'যোগ করুন',
      'search': 'অনুসন্ধান',
      'filter': 'ফিল্টার',
      'date': 'তারিখ',
      'amount': 'পরিমাণ',
      'category': 'শ্রেণী',
      'description': 'বিবরণ',
      'total': 'মোট',
    },
  };

  static LocalizationService get instance => _instance;

  /// Get current locale
  Locale get currentLocale => _currentLocale;

  /// Set locale
  void setLocale(Locale locale) {
    if (supportedLocales.contains(locale)) {
      _currentLocale = locale;
    }
  }

  /// Translate key
  String translate(String key) {
    final languageCode = _currentLocale.languageCode;
    return _translations[languageCode]?[key] ??
        _translations['en']?[key] ??
        key;
  }

  /// Get language name
  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी';
      case 'ta':
        return 'தமிழ்';
      case 'te':
        return 'తెలుగు';
      case 'mr':
        return 'मराठी';
      case 'bn':
        return 'বাংলা';
      case 'gu':
        return 'ગુજરાતી';
      case 'kn':
        return 'ಕನ್ನಡ';
      default:
        return 'English';
    }
  }

  /// Get all supported languages
  List<LanguageOption> getSupportedLanguages() {
    return supportedLocales.map((locale) {
      return LanguageOption(
        code: locale.languageCode,
        name: getLanguageName(locale.languageCode),
        locale: locale,
      );
    }).toList();
  }
}

/// Language option model
class LanguageOption {
  LanguageOption({
    required this.code,
    required this.name,
    required this.locale,
  });
  final String code;
  final String name;
  final Locale locale;
}

/// Extension for easy translation access
extension LocalizationExtension on String {
  String tr() {
    return LocalizationService.instance.translate(this);
  }
}
