import 'package:budget_ledger/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Quds Ledger renders desktop layout, switches currency/tabs, and adds an entry',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(QudsLedgerApp());
      await tester.pumpAndSettle();

      expect(find.text('Quds Ledger'), findsWidgets);
      expect(find.text('NET BALANCE'), findsOneWidget);
      expect(find.text('Spending Breakdown'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);

      // Switch currency to EUR via desktop rail chip and verify exact conversion badge updates.
      await tester.tap(find.text('EUR'));
      await tester.pumpAndSettle();
      expect(find.text('Fraction Exact · EUR'), findsOneWidget);

      // Navigate to Budgets & JSON tab.
      await tester.tap(find.text('Budgets & JSON'));
      await tester.pumpAndSettle();
      expect(
        find.text('Exact Rational Exchange Rates (quds_ledger)'),
        findsOneWidget,
      );

      // Open New Entry dialog and add a transaction.
      await tester.tap(find.text('New Entry'));
      await tester.pumpAndSettle();
      expect(find.text('New Transaction'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Coffee Beans');
      await tester.enterText(fields.at(1), '18.50');
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      // Navigate to Transactions tab and confirm the new entry is listed.
      await tester.tap(find.text('Transactions'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee Beans'), findsOneWidget);
    },
  );

  testWidgets('Quds Ledger renders mobile layout with bottom navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(QudsLedgerApp());
    await tester.pumpAndSettle();

    expect(find.text('Quds Ledger'), findsOneWidget);
    expect(find.text('Add Entry'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
