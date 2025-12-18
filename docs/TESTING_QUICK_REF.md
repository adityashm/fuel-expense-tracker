# Testing Quick Reference

## ⚡ Quick Commands

```bash
# Run ALL tests
flutter test test/unit_tests/ test/widget_tests/

# Run specific test file
flutter test test/unit_tests/models/expense_test.dart

# Run with verbose output
flutter test test/ -v

# Run tests and watch for changes
flutter test test/ --watch

# Run specific test by name
flutter test test/unit_tests/ -k "expense_creation"

# Run tests with coverage
flutter test test/unit_tests/ --coverage
```

## 📊 Test Summary

| Test Group | Count | Command | Status |
|---|---|---|---|
| **All Tests** | 18 | `flutter test test/unit_tests/ test/widget_tests/` | ✅ |
| Expense Model | 4 | `flutter test test/unit_tests/models/expense_test.dart` | ✅ |
| Validation | 4 | `flutter test test/unit_tests/utils/validation_test.dart` | ✅ |
| Formatting | 4 | `flutter test test/unit_tests/utils/formatter_test.dart` | ✅ |
| Basic Widgets | 4 | `flutter test test/widget_tests/basic_widgets_test.dart` | ✅ |
| Navigation | 2 | `flutter test test/widget_tests/navigation_test.dart` | ✅ |

## 🧪 What's Tested

✅ **Models**: Expense creation, equality, copying  
✅ **Validation**: Amounts, phones, emails, dates  
✅ **Formatting**: Currency, dates, phones, percentages  
✅ **Widgets**: Buttons, text, lists, navigation  
✅ **Navigation**: Screen transitions, back button  

## 📂 Test Files Location

```
test/
├── unit_tests/models/expense_test.dart
├── unit_tests/utils/validation_test.dart
├── unit_tests/utils/formatter_test.dart
├── widget_tests/basic_widgets_test.dart
└── widget_tests/navigation_test.dart
```

## 🎯 Next: Add More Tests

```dart
// Add test file for services
test/unit_tests/services/firebase_test.dart
test/unit_tests/services/database_test.dart

// Add integration tests
integration_test/auth_test.dart
integration_test/expense_workflow_test.dart
```

## 📈 Current Coverage

- **Models**: ████████░░ 100%
- **Utils**: ████████░░ 100%
- **Widgets**: ███████░░░ 90%
- **Services**: ░░░░░░░░░░ 0%

---

**All tests passing! Ready to add more coverage.** ✨
