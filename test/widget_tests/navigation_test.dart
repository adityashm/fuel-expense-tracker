import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App Navigation Tests', () {
    testWidgets('Navigate between screens', (WidgetTester tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            appBar: AppBar(title: const Text('Home')),
            body: ElevatedButton(
              onPressed: () {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('Detail')),
                      body: const Center(child: Text('Detail Page')),
                    ),
                  ),
                );
              },
              child: const Text('Go to Detail'),
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Detail Page'), findsNothing);

      await tester.tap(find.text('Go to Detail'));
      await tester.pumpAndSettle();

      expect(find.text('Detail'), findsOneWidget);
      expect(find.text('Detail Page'), findsOneWidget);
    });

    testWidgets('Back navigation', (WidgetTester tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            appBar: AppBar(title: const Text('Page 1')),
            body: ElevatedButton(
              onPressed: () {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Page 2'),
                        leading: BackButton(
                          onPressed: () => navigatorKey.currentState?.pop(),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Next'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Page 2'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Page 1'), findsOneWidget);
    });
  });
}
