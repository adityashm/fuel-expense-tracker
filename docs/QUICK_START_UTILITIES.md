# 🚀 QUICK START GUIDE - Using New Utilities

## ErrorHandler - Centralized Error Handling

### Basic Usage
```dart
import 'package:fuel_expense_tracker/utils/error_handler.dart';

// In any async operation
try {
  await DatabaseService.instance.addExpense(expense);
  ErrorHandler.showSuccess(context, 'Expense saved!');
} catch (e, stack) {
  ErrorHandler.handle(e, stack, context);
}
```

### With Retry
```dart
try {
  await FirebaseService.instance.syncData();
  ErrorHandler.showSuccess(context, 'Data synced successfully');
} catch (e, stack) {
  ErrorHandler.handle(
    e, 
    stack, 
    context,
    customMessage: 'Failed to sync data',
    onRetry: () => _syncData(),  // Retry function
  );
}
```

### Show Messages
```dart
ErrorHandler.showSuccess(context, 'Profile updated');
ErrorHandler.showWarning(context, 'Low fuel detected');
ErrorHandler.showInfo(context, 'New update available');
```

---

## Formatters - Consistent Formatting

### Currency
```dart
import 'package:fuel_expense_tracker/utils/formatters.dart';

Text(Formatters.currency(1234.56));  // ₹1,234.56
Text(Formatters.currency(1234.56, symbol: '\$'));  // $1,234.56
Text(Formatters.currencyNoSymbol(1234.56));  // 1,234.56
```

### Date & Time
```dart
Text(Formatters.date(DateTime.now()));  // 15 Dec 2025
Text(Formatters.dateTime(DateTime.now()));  // 15 Dec 2025, 02:30 PM
Text(Formatters.time(DateTime.now()));  // 02:30 PM
Text(Formatters.monthYear(DateTime.now()));  // Dec 2025
Text(Formatters.fullDate(DateTime.now()));  // Sunday, 15 December 2025
Text(Formatters.shortDate(DateTime.now()));  // 15/12/2025
Text(Formatters.relativeTime(expense.date));  // 2 hours ago
```

### Fuel & Distance
```dart
Text(Formatters.fuelVolume(45.5));  // 45.50 L
Text(Formatters.fuelEfficiency(18.5));  // 18.50 km/L
Text(Formatters.costPerLiter(95.5));  // 95.50/L
Text(Formatters.distance(125.5));  // 125.5 km
Text(Formatters.distance(0.8));  // 800 m
```

### Numbers
```dart
Text(Formatters.decimal(1234.567, decimals: 2));  // 1,234.57
Text(Formatters.integer(1234567));  // 1,234,567
Text(Formatters.percentage(0.255));  // 25.5%
Text(Formatters.compactNumber(1500));  // 1.5K
Text(Formatters.compactNumber(1500000));  // 1.5M
```

### Other
```dart
Text(Formatters.duration(135));  // 2 hr 15 min
Text(Formatters.fileSize(1024*1024*5));  // 5.0 MB
Text(Formatters.truncate('Very long text...', 20));  // Very long text...
Text(Formatters.vehicleRegistration('DL01AB1234'));  // DL 01 AB 1234
```

---

## Validators - Form Validation

### Basic Validation
```dart
import 'package:fuel_expense_tracker/utils/validators.dart';

TextFormField(
  validator: Validators.required,  // Basic required field
  decoration: InputDecoration(labelText: 'Name'),
)

TextFormField(
  validator: (value) => Validators.required(value, field: 'Email'),
  decoration: InputDecoration(labelText: 'Email'),
)
```

### Number Validation
```dart
TextFormField(
  validator: Validators.positiveNumber,
  decoration: InputDecoration(labelText: 'Amount'),
)

TextFormField(
  validator: (value) => Validators.range(value, 0, 100),
  decoration: InputDecoration(labelText: 'Percentage'),
)
```

### Odometer Validation
```dart
TextFormField(
  validator: Validators.odometerReading(previousReading),
  decoration: InputDecoration(labelText: 'Current Reading'),
)
```

### Combined Validators
```dart
TextFormField(
  validator: Validators.combine([
    Validators.required,
    Validators.positiveNumber,
    (value) => Validators.range(value, 1, 1000, field: 'Liters'),
  ]),
)
```

---

## FirebaseCache - Reduce Firebase Reads

### Basic Usage
```dart
import 'package:fuel_expense_tracker/utils/firebase_cache.dart';

// In your service/provider
Future<List<Expense>> getExpenses() async {
  return FirebaseCache.instance.getOrFetch(
    CacheKeys.expenses(deviceId),
    () => _fetchFromFirebase(),  // Only called if cache expired
    ttl: Duration(minutes: 5),
  );
}
```

### Cache Invalidation
```dart
// After creating/updating/deleting data
await DatabaseService.instance.addExpense(expense);

// Invalidate specific cache
FirebaseCache.instance.invalidate(CacheKeys.expenses(deviceId));

// Invalidate all expense caches
FirebaseCache.instance.invalidatePattern('expenses_*');

// Clear everything
FirebaseCache.instance.clearAll();
```

### Pre-defined Cache Keys
```dart
CacheKeys.expenses(deviceId)
CacheKeys.fuelExpenses(deviceId)
CacheKeys.generalExpenses(deviceId)
CacheKeys.householdExpenses(deviceId)
CacheKeys.vehicles(deviceId)
CacheKeys.vehicle(vehicleId)
CacheKeys.familyMembers(deviceId)
CacheKeys.budgets(deviceId)
CacheKeys.trips(vehicleId)
CacheKeys.reminders(deviceId)
```

---

## Migration Guide - Update Existing Code

### Before: Manual Error Handling
```dart
// OLD CODE ❌
try {
  await saveExpense();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Saved'), backgroundColor: Colors.green),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
  );
}
```

### After: ErrorHandler
```dart
// NEW CODE ✅
try {
  await saveExpense();
  ErrorHandler.showSuccess(context, 'Expense saved successfully');
} catch (e, stack) {
  ErrorHandler.handle(e, stack, context);
}
```

---

### Before: Manual Formatting
```dart
// OLD CODE ❌
Text('₹${amount.toStringAsFixed(2)}')
Text('${DateFormat('dd MMM yyyy').format(date)}')
Text('${liters.toStringAsFixed(2)} L')
```

### After: Formatters
```dart
// NEW CODE ✅
Text(Formatters.currency(amount))
Text(Formatters.date(date))
Text(Formatters.fuelVolume(liters))
```

---

### Before: Manual Validation
```dart
// OLD CODE ❌
validator: (value) {
  if (value == null || value.isEmpty) {
    return 'Amount is required';
  }
  final num = double.tryParse(value);
  if (num == null) {
    return 'Enter valid number';
  }
  if (num <= 0) {
    return 'Amount must be positive';
  }
  return null;
}
```

### After: Validators
```dart
// NEW CODE ✅
validator: Validators.positiveNumber
// OR with custom field name
validator: (v) => Validators.positiveNumber(v, field: 'Amount')
```

---

### Before: Firebase Without Caching
```dart
// OLD CODE ❌
Future<List<Vehicle>> getVehicles() async {
  final snapshot = await firestore
      .collection('vehicles')
      .get();  // EVERY TIME!
  return snapshot.docs.map((d) => Vehicle.fromMap(d.data())).toList();
}
```

### After: Firebase With Caching
```dart
// NEW CODE ✅
Future<List<Vehicle>> getVehicles() async {
  return FirebaseCache.instance.getOrFetch(
    CacheKeys.vehicles(deviceId),
    () async {
      final snapshot = await firestore
          .collection('vehicles')
          .limit(50)  // Also add limits!
          .get();
      return snapshot.docs.map((d) => Vehicle.fromMap(d.data())).toList();
    },
    ttl: Duration(minutes: 5),  // Cache for 5 minutes
  );
}
```

---

## Best Practices

### 1. Always Use ErrorHandler
```dart
✅ DO: ErrorHandler.handle(e, stack, context)
❌ DON'T: print('Error: $e')
❌ DON'T: Manual SnackBar creation
```

### 2. Use Formatters Everywhere
```dart
✅ DO: Text(Formatters.currency(amount))
❌ DON'T: Text('₹${amount.toStringAsFixed(2)}')
```

### 3. Combine Validators
```dart
✅ DO: Validators.combine([required, positiveNumber, range])
❌ DON'T: Multiple nested if statements
```

### 4. Cache Firebase Reads
```dart
✅ DO: FirebaseCache.instance.getOrFetch(...)
❌ DON'T: Direct .get() calls every time
```

### 5. Invalidate Cache After Mutations
```dart
✅ DO: 
await saveExpense();
FirebaseCache.instance.invalidate(CacheKeys.expenses(deviceId));

❌ DON'T: Forget to invalidate (stale data!)
```

---

## Common Patterns

### CRUD Operations with Error Handling
```dart
Future<void> createExpense(Expense expense) async {
  try {
    await DatabaseService.instance.addExpense(expense);
    await FirebaseService.instance.syncExpense(expense);
    
    // Invalidate cache
    FirebaseCache.instance.invalidate(CacheKeys.expenses(deviceId));
    
    if (mounted) {
      ErrorHandler.showSuccess(context, 'Expense created successfully');
      Navigator.pop(context);
    }
  } catch (e, stack) {
    ErrorHandler.handle(e, stack, context, onRetry: () => createExpense(expense));
  }
}
```

### Form with Validation
```dart
final _formKey = GlobalKey<FormState>();

Form(
  key: _formKey,
  child: Column(
    children: [
      TextFormField(
        decoration: InputDecoration(labelText: 'Amount'),
        validator: Validators.combine([
          Validators.required,
          Validators.positiveNumber,
        ]),
      ),
      TextFormField(
        decoration: InputDecoration(labelText: 'Description'),
        validator: (v) => Validators.required(v, field: 'Description'),
      ),
      ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            _saveForm();
          }
        },
        child: Text('Save'),
      ),
    ],
  ),
)
```

### Display Formatted Data
```dart
Card(
  child: Column(
    children: [
      Text('Amount: ${Formatters.currency(expense.amount)}'),
      Text('Date: ${Formatters.date(expense.date)}'),
      Text('Added: ${Formatters.relativeTime(expense.createdAt)}'),
      if (expense.fuelLiters != null)
        Text('Fuel: ${Formatters.fuelVolume(expense.fuelLiters!)}'),
      if (expense.efficiency != null)
        Text('Efficiency: ${Formatters.fuelEfficiency(expense.efficiency!)}'),
    ],
  ),
)
```

---

## Performance Tips

1. **Use const constructors** wherever possible
2. **Cache Firebase results** with FirebaseCache
3. **Dispose controllers** in dispose() method
4. **Use Formatters** instead of creating NumberFormat instances
5. **Combine validators** instead of multiple checks
6. **Invalidate cache** after data mutations

---

## Troubleshooting

### "Cache not updating after save"
→ Did you invalidate the cache?
```dart
FirebaseCache.instance.invalidate(CacheKeys.expenses(deviceId));
```

### "Error messages not showing"
→ Check if context is mounted:
```dart
if (mounted) {
  ErrorHandler.handle(e, stack, context);
}
```

### "Validation not working"
→ Make sure to call validator in Form:
```dart
if (_formKey.currentState!.validate()) {
  // Form is valid
}
```

---

*Quick Reference Guide v1.0*  
*Updated: December 15, 2025*
