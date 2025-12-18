# Testing Guide

## Test Structure

```
test/
├── unit_tests/
│   ├── models/
│   │   └── expense_test.dart
│   └── utils/
│       ├── validation_test.dart
│       └── formatter_test.dart
├── widget_tests/
│   ├── basic_widgets_test.dart
│   └── navigation_test.dart
└── widget_test.dart

integration_test/
└── app_test.dart
```

## Running Tests

### Run all tests
```bash
flutter test
```

### Run specific test file
```bash
flutter test test/unit_tests/models/expense_test.dart
```

### Run unit tests only
```bash
flutter test test/unit_tests/
```

### Run widget tests only
```bash
flutter test test/widget_tests/
```

### Run integration tests (device/emulator required)
```bash
flutter test integration_test/app_test.dart
```

### Run with coverage
```bash
flutter test --coverage
```

## Test Categories

### Unit Tests
- **expense_test.dart** - Expense model validation
- **validation_test.dart** - Input validation (amount, email, phone, description)
- **formatter_test.dart** - Number/currency formatting utilities

### Widget Tests
- **basic_widgets_test.dart** - Widget rendering and interaction
- **navigation_test.dart** - Screen navigation and routing
- **widget_test.dart** - App-level widget tests (existing)

### Integration Tests
- **app_test.dart** - Full app flow testing
- Tests app launch, screen rendering, and overall stability

## Test Coverage Target
- Unit Tests: 80%+ coverage
- Widget Tests: Cover key UI flows
- Integration Tests: Critical user journeys

## Adding New Tests

1. **For models/logic**: Add to `test/unit_tests/`
2. **For UI widgets**: Add to `test/widget_tests/`
3. **For end-to-end flows**: Add to `integration_test/`

## CI/CD Integration

To add to GitHub Actions or other CI/CD:
```yaml
- name: Run tests
  run: flutter test --coverage

- name: Upload coverage
  uses: codecov/codecov-action@v3
```
