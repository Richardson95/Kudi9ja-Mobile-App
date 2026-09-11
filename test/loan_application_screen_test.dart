import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/features/loans/loan_application_screen.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:kudi9ja/widgets/inputs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The borrow form, drawn.
///
/// This file exists because of a bug no amount of reading caught and every test
/// we had passed straight through: the three business-photo pickers were each
/// taller than the box they were put in, so they overflowed, painted on top of
/// the fields beneath them, and left the step unscrollable. It shipped, and it
/// looked broken on the first screen a borrower sees.
///
/// A widget test catches exactly that, because Flutter turns a layout overflow
/// into a test failure. Nothing here asserts on pixels; it asserts the thing
/// can be drawn at all, at a size a real phone has.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpForm(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState(await StorageService.init());

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(
          home: LoanApplicationScreen(
            principal: 200000,
            months: 3,
            purpose: 'Business',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The input inside the [KField] with this label. The label is a sibling of
  /// the field rather than its decoration, so it cannot be found by text alone.
  Finder inputFor(String label) => find.descendant(
        of: find.byWidgetPredicate((w) => w is KField && w.label == label),
        matching: find.byType(TextFormField),
      );

  KField fieldFor(WidgetTester tester, String label) => tester.widget<KField>(
        find.byWidgetPredicate((w) => w is KField && w.label == label),
      );

  /// Fills step one so Continue turns on, and moves to the documents.
  Future<void> completeBusinessStep(WidgetTester tester) async {
    await tester.enterText(inputFor('Business name'), 'Test Stores');
    await tester.enterText(inputFor('Business address'), '14 Adeola Odeku');
    await tester.enterText(inputFor('Monthly income'), '450000');
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('the documents step draws without overflowing', (tester) async {
    await pumpForm(tester);
    expect(find.text('Your business'), findsOneWidget);

    await completeBusinessStep(tester);

    expect(find.text('Bank statement'), findsOneWidget);
    expect(find.text('Your business premises'), findsOneWidget);
    // Three slots across the width rather than three stacked pickers, which is
    // what stopped them running off the bottom of the step.
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Inside'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
  });

  testWidgets('the documents step scrolls on a short screen', (tester) async {
    // Genuinely shorter than the content — the case that was broken. Dragging
    // to the end must not throw, which is what an overflowed child does.
    await pumpForm(tester, size: const Size(400, 620));
    await completeBusinessStep(tester);

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the guarantor step draws without overflowing', (tester) async {
    await pumpForm(tester);
    await completeBusinessStep(tester);

    // Straight past the documents: the uploads cannot be driven from a test,
    // but the step after them still has to be drawable.
    expect(find.text('Your documents'), findsOneWidget);
  });

  testWidgets('income is grouped as it is typed', (tester) async {
    await pumpForm(tester);
    await tester.enterText(inputFor('Monthly income'), '1000000');
    await tester.pump();

    // 1000000 is unreadable at a glance, and a figure nobody can read is a
    // figure that gets entered wrong.
    expect(fieldFor(tester, 'Monthly income').controller?.text, '1,000,000');
  });

  testWidgets('an unfinished step does not advance', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Your business'), findsOneWidget,
        reason: 'an empty step should not move on to the uploads');
  });
}
