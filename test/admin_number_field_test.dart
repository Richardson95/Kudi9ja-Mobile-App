import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/features/admin/admin_number_field.dart';

/// One field on its own, holding its value the way the settings screen does:
/// the parent owns the number and rebuilds the field with it.
Future<List<double>> _pump(
  WidgetTester tester, {
  required double value,
  AdminNumberKind kind = AdminNumberKind.whole,
  double? min,
}) async {
  final seen = <double>[];
  var current = value;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AdminNumberField(
            value: current,
            kind: kind,
            min: min,
            onChanged: (v) => setState(() {
              current = v;
              seen.add(v);
            }),
          ),
        ),
      ),
    ),
  );
  return seen;
}

void main() {
  group('typed settings', () {
    testWidgets('a rate is typed as a percentage and stored as a fraction', (tester) async {
      final seen = await _pump(tester, value: 0.17, kind: AdminNumberKind.percent);
      expect(find.text('17'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '85.5');
      expect(seen.last, closeTo(0.855, 1e-12));
    });

    testWidgets('an amount is grouped as it is typed', (tester) async {
      final seen = await _pump(tester, value: 5000, kind: AdminNumberKind.money);
      expect(find.text('5,000'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '250000');
      await tester.pump();
      expect(find.text('250,000'), findsOneWidget);
      expect(seen.last, 250000);
    });

    testWidgets('a figure under the floor is kept out of the draft', (tester) async {
      final seen = await _pump(tester, value: 15, min: 10);

      await tester.enterText(find.byType(TextField), '5');
      expect(seen, isEmpty);

      await tester.enterText(find.byType(TextField), '12');
      expect(seen, [12]);
    });

    testWidgets('an empty field changes nothing', (tester) async {
      final seen = await _pump(tester, value: 3);
      await tester.enterText(find.byType(TextField), '');
      expect(seen, isEmpty);
    });
  });

  testWidgets('the rate card has a field for every month, on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final edits = <(int, double)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: RateByTermGrid(
              rates: const {1: 0.10, 2: 0.15},
              maxTenureMonths: 12,
              enabled: true,
              onChanged: (m, r) => edits.add((m, r)),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AdminNumberField), findsNWidgets(12));
    expect(find.text('12 months'), findsOneWidget);
    // Months 3 to 12 have no rate of their own yet.
    expect(find.text('Needs a rate'), findsNWidgets(10));

    await tester.enterText(find.byType(TextField).at(1), '18');
    expect(edits.single.$1, 2);
    expect(edits.single.$2, closeTo(0.18, 1e-12));
  });

  group('rate card lengthened', () {
    test('every new month starts at the rate before it', () {
      final rates = ratesUpTo({1: 0.10, 2: 0.15, 3: 0.20}, 5);
      expect(rates, {1: 0.10, 2: 0.15, 3: 0.20, 4: 0.20, 5: 0.20});
    });

    test('a gap in the card is filled from below, not left empty', () {
      final rates = ratesUpTo({1: 0.10, 4: 0.30}, 4);
      expect(rates, {1: 0.10, 2: 0.10, 3: 0.10, 4: 0.30});
    });

    test('rates already set are never overwritten', () {
      final rates = ratesUpTo({1: 0.10, 2: 0.15, 3: 0.20}, 2);
      expect(rates, {1: 0.10, 2: 0.15, 3: 0.20});
    });
  });
}
