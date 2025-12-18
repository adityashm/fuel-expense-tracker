class ExpenseValidators {
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Enter a valid amount';
    }
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    if (amount > 999999.99) {
      return 'Amount is too large';
    }
    return null;
  }

  static String? validateDescription(String? value, {bool required = false}) {
    if (required && (value == null || value.isEmpty)) {
      return 'Description is required';
    }
    if (value != null && value.length > 500) {
      return 'Description too long (max 500 characters)';
    }
    return null;
  }

  static String? validateLiters(String? value) {
    if (value == null || value.isEmpty) {
      return 'Liters is required';
    }
    final liters = double.tryParse(value);
    if (liters == null) {
      return 'Enter a valid number';
    }
    if (liters <= 0) {
      return 'Liters must be greater than 0';
    }
    if (liters > 9999) {
      return 'Liters value is too large';
    }
    return null;
  }

  static String? validateOdometer(String? value) {
    if (value == null || value.isEmpty) {
      return 'Odometer reading is required';
    }
    final odometer = double.tryParse(value);
    if (odometer == null) {
      return 'Enter a valid number';
    }
    if (odometer < 0) {
      return 'Odometer cannot be negative';
    }
    if (odometer > 9999999) {
      return 'Odometer value is too large';
    }
    return null;
  }

  static String? validateVehicleName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vehicle name is required';
    }
    if (value.length < 2) {
      return 'Vehicle name too short';
    }
    if (value.length > 50) {
      return 'Vehicle name too long (max 50 characters)';
    }
    return null;
  }

  static String? validateRegistrationNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Registration number is required';
    }
    if (value.length < 3) {
      return 'Registration number too short';
    }
    if (value.length > 20) {
      return 'Registration number too long (max 20 characters)';
    }
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    if (value.length < 10) {
      return 'Phone number too short';
    }
    if (value.length > 15) {
      return 'Phone number too long';
    }
    if (!RegExp(r'^[0-9+\-\(\) ]+$').hasMatch(value)) {
      return 'Invalid phone number format';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }
}
