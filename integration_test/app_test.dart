import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bridge_phone/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('App launches successfully', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify app launched
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Navigate through main tabs', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find navigation items (adjust based on actual UI)
      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isNotEmpty) {
        // Test tab navigation
        await tester.tap(find.text('SMS').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Calls').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Settings').first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Settings screen loads correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to settings if needed
      final settingsButton = find.text('Settings');
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton.first);
        await tester.pumpAndSettle();
      }

      // Verify settings elements are present
      expect(find.text('Connection'), findsWidgets);
    });

    testWidgets('Multiple app open/close cycles', (WidgetTester tester) async {
      // Test app stability over multiple cycles
      for (int i = 0; i < 3; i++) {
        app.main();
        await tester.pumpAndSettle();
        
        // Verify app is stable
        expect(find.byType(MaterialApp), findsOneWidget);
        
        // Simulate small delay
        await Future.delayed(const Duration(milliseconds: 500));
      }
    });

    testWidgets('Rapid tap handling', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find any tappable element
      final tappable = find.byType(GestureDetector);
      if (tappable.evaluate().isNotEmpty) {
        // Rapid taps to test stability
        for (int i = 0; i < 10; i++) {
          await tester.tap(tappable.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        
        // App should still be responsive
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });
  });
}
