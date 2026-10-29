import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/data/models/loan_application.dart';
import 'package:kudi9ja/data/models/platform_settings.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/features/admin/admin_change_terms_sheet.dart';
import 'package:kudi9ja/features/loans/terms_offer_card.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two new surfaces of a changed-terms offer, drawn at a phone's width.
///
/// Both put full naira amounts side by side, which is exactly what overflows
/// on a narrow screen, and Flutter fails a test on any overflow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final application = LoanApplication(
    id: 'a-1',
    amount: 4500000,
    tenureMonths: 3,
    purpose: 'Stock',
    status: LoanApplicationStatus.offered,
    submittedAt: DateTime(2026, 10, 29),
    customerName: 'Chioma Grace Adeyemi',
    repaymentFrequency: RepaymentFrequency.weekly,
    offer: TermsOffer(
      months: 6,
      flatRate: 0.3,
      managementFee: 90000,
      repaymentFeeRate: 0.025,
      offeredAt: DateTime(2026, 10, 29, 10),
      note: 'Six months suits your income better.',
    ),
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState(await StorageService.init());
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  testWidgets('the customer sees both sets of terms and both answers',
      (tester) async {
    await pump(
      tester,
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: TermsOfferCard(application: application),
      ),
    );

    expect(find.text('YOU ASKED FOR'), findsOneWidget);
    expect(find.text('NEW TERMS'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('2.5%'), findsOneWidget);
    expect(find.text('Six months suits your income better.'), findsOneWidget);
    expect(find.text('Agree'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('the admin sheet starts from the offer and will not resend it',
      (tester) async {
    await pump(
      tester,
      ChangeTermsSheet(application: application, terms: settings.lending),
    );

    expect(find.text('Change the terms'), findsOneWidget);
    expect(find.text('Paid out'), findsOneWidget);
    // Unchanged from what was already offered, so there is nothing to send.
    expect(
      find.text('Change at least one of the four to send an offer.'),
      findsOneWidget,
    );
  });
}
