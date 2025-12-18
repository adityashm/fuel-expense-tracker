import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'Fuel Tracker',
      'home': 'Home',
      'vehicles': 'Vehicles',
      'expenses': 'Expenses',
      'analytics': 'Analytics',
      'settings': 'Settings',
      'add_user': 'Add User',
      'add_vehicle': 'Add Vehicle',
      'add_fuel_expense': 'Add Fuel Expense',
      'add_general_expense': 'Add General Expense',
      'add_household_expense': 'Add Household Expense',
      'select_user': 'Select User',
      'name': 'Name',
      'vehicle_name': 'Vehicle Name',
      'registration_number': 'Registration Number',
      'vehicle_type': 'Vehicle Type',
      'bike': 'Bike',
      'car': 'Car',
      'current_odometer': 'Current Odometer',
      'fuel_type': 'Fuel Type',
      'petrol': 'Petrol',
      'diesel': 'Diesel',
      'cng': 'CNG',
      'amount': 'Amount',
      'liters': 'Liters',
      'odometer_reading': 'Odometer Reading',
      'pump_name': 'Pump Name',
      'location': 'Location',
      'notes': 'Notes',
      'category': 'Category',
      'description': 'Description',
      'date': 'Date',
      'scan_receipt': 'Scan Receipt',
      'take_photo': 'Take Photo',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'fuel_average': 'Fuel Average',
      'km_per_liter': 'km/liter',
      'total_expenses': 'Total Expenses',
      'fuel_expenses': 'Fuel Expenses',
      'general_expenses': 'General Expenses',
      'household_expenses': 'Household Expenses',
      'monthly_expenses': 'Monthly Expenses',
      'export_data': 'Export Data',
      'backup': 'Backup',
      'restore': 'Restore',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'maintenance': 'Maintenance',
      'insurance': 'Insurance',
      'parking': 'Parking',
      'tolls': 'Tolls',
      'servicing': 'Servicing',
      'groceries': 'Groceries',
      'utilities': 'Utilities',
      'healthcare': 'Healthcare',
      'education': 'Education',
      'entertainment': 'Entertainment',
      'shopping': 'Shopping',
      'food': 'Food',
      'transport': 'Transport',
      'other': 'Other',
      'add_fuel': 'Add Fuel',
      'vehicle_expense': 'Vehicle Expense',
      'household_expense': 'Household Expense',
      'voice_entry': 'Voice Entry',
      'choose_fuel_vehicle_hint': 'Choose a petrol/diesel vehicle for fuel expense',
      'choose_vehicle_hint': 'Choose a vehicle for this expense',
      'no_fuel_vehicles_message': 'No petrol/diesel vehicles found.\nElectric vehicles cannot have fuel expenses.',
      'no_vehicles_message': 'No vehicles found. Please add a vehicle first.',
      'select_vehicle': 'Select Vehicle',
    },
    'hi': {
      'app_name': 'ईंधन ट्रैकर',
      'home': 'होम',
      'vehicles': 'वाहन',
      'expenses': 'खर्च',
      'analytics': 'विश्लेषण',
      'settings': 'सेटिंग्स',
      'add_user': 'उपयोगकर्ता जोड़ें',
      'add_vehicle': 'वाहन जोड़ें',
      'add_fuel_expense': 'ईंधन खर्च जोड़ें',
      'add_general_expense': 'सामान्य खर्च जोड़ें',
      'add_household_expense': 'घरेलू खर्च जोड़ें',
      'select_user': 'उपयोगकर्ता चुनें',
      'name': 'नाम',
      'vehicle_name': 'वाहन का नाम',
      'registration_number': 'पंजीकरण संख्या',
      'vehicle_type': 'वाहन का प्रकार',
      'bike': 'बाइक',
      'car': 'कार',
      'current_odometer': 'वर्तमान ओडोमीटर',
      'fuel_type': 'ईंधन का प्रकार',
      'petrol': 'पेट्रोल',
      'diesel': 'डीजल',
      'cng': 'सीएनजी',
      'amount': 'राशि',
      'liters': 'लीटर',
      'odometer_reading': 'ओडोमीटर रीडिंग',
      'pump_name': 'पंप का नाम',
      'location': 'स्थान',
      'notes': 'नोट्स',
      'category': 'श्रेणी',
      'description': 'विवरण',
      'date': 'तारीख',
      'scan_receipt': 'रसीद स्कैन करें',
      'take_photo': 'फोटो लें',
      'save': 'सेव करें',
      'cancel': 'रद्द करें',
      'delete': 'मिटाएं',
      'edit': 'संपादित करें',
      'fuel_average': 'ईंधन औसत',
      'km_per_liter': 'किमी/लीटर',
      'total_expenses': 'कुल खर्च',
      'fuel_expenses': 'ईंधन खर्च',
      'general_expenses': 'सामान्य खर्च',
      'household_expenses': 'घरेलू खर्च',
      'monthly_expenses': 'मासिक खर्च',
      'export_data': 'डेटा निर्यात करें',
      'backup': 'बैकअप',
      'restore': 'पुनर्स्थापित करें',
      'dark_mode': 'डार्क मोड',
      'language': 'भाषा',
      'maintenance': 'रखरखाव',
      'insurance': 'बीमा',
      'parking': 'पार्किंग',
      'tolls': 'टोल',
      'servicing': 'सर्विसिंग',
      'groceries': 'किराने का सामान',
      'utilities': 'उपयोगिताएं',
      'healthcare': 'स्वास्थ्य देखभाल',
      'education': 'शिक्षा',
      'entertainment': 'मनोरंजन',
      'shopping': 'खरीदारी',
      'food': 'भोजन',
      'transport': 'परिवहन',
      'other': 'अन्य',
      'add_fuel': 'ईंधन जोड़ें',
      'vehicle_expense': 'वाहन खर्च',
      'household_expense': 'घरेलू खर्च',
      'voice_entry': 'वॉयस एंट्री',
      'choose_fuel_vehicle_hint': 'ईंधन खर्च के लिए पेट्रोल/डीजल वाहन चुनें',
      'choose_vehicle_hint': 'इस खर्च के लिए एक वाहन चुनें',
      'no_fuel_vehicles_message': 'कोई पेट्रोल/डीजल वाहन नहीं मिला।\nइलेक्ट्रिक वाहनों में ईंधन खर्च नहीं हो सकता।',
      'no_vehicles_message': 'कोई वाहन नहीं मिला। कृपया पहले एक वाहन जोड़ें।',
      'select_vehicle': 'वाहन चुनें',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: locale.languageCode,
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  String formatDate(DateTime date) {
    return DateFormat.yMMMd(locale.languageCode).format(date);
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
