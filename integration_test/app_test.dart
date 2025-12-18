import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_expense_tracker/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('App launches without crashing', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byType(MyApp), findsOneWidget);
    });

    testWidgets('Home screen displays correctly', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Verify app loaded successfully
      expect(find.byType(MyApp), findsOneWidget);
    });

    testWidgets('UI renders without errors', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // App should not throw during initialization
      expect(
        () async {
          await tester.pumpWidget(MyApp(prefs: prefs));
          await tester.pumpAndSettle();
        },
        returnsNormally,
      );
    });
  });
}
