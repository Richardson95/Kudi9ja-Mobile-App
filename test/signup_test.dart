import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/core/theme/app_theme.dart';
import 'package:kudi9ja/features/auth/signup/signup_draft.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/features/auth/signup/steps/identity_step.dart';
import 'package:kudi9ja/features/savings/thrift/create_circle_screen.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child));

void main() {
  group('Ajo circle members', () {
    testWidgets('the name field says who may be added, and how', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final app = AppState(await StorageService.init());

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: app,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const CreateCircleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The members section sits below the fold.
      await tester.dragUntilVisible(
        find.text('Add full name'),
        find.byType(Scrollable).first,
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();

      // A circle only debits real Kudi9ja accounts, so the field has to say
      // so at the point the name is typed.
      expect(find.text('Add full name'), findsOneWidget);
      expect(
        find.textContaining('must already have a Kudi9ja account'),
        findsOneWidget,
      );
      expect(
        find.textContaining('exactly as it is registered'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
  });


  group('Identity step', () {
    testWidgets('the confirmation shows the BVN and NIN that were checked', (
      tester,
    ) async {
      final draft = SignupDraft()
        ..fullName = 'Ada Customer'
        ..stateOfResidence = 'Lagos';

      await tester.pumpWidget(
        _host(IdentityStep(draft: draft, onNext: () {})),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, '11 digits').first,
        '22112233445',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '11 digits').last,
        '11223344556',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          '12 Adeola Odeku Street, Victoria Island',
        ),
        '1 Test Street',
      );
      await tester.pump();

      await tester.tap(find.text('Verify identity'));
      await tester.pump();
      // The stand-in identity lookup.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('Identity confirmed'), findsOneWidget);

      // The bug this guards: the draft was only written on Continue, so the
      // confirmation table rendered an empty BVN and NIN.
      expect(draft.bvn, '22112233445');
      expect(draft.nin, '11223344556');
      expect(draft.address, '1 Test Street');

      expect(find.text('221*****445'), findsOneWidget);
      expect(find.text('112*****556'), findsOneWidget);
      expect(find.text('Ada Customer'), findsOneWidget);
      expect(find.text('Lagos'), findsOneWidget);

      // Nothing on that table may render as blank.
      expect(find.text('-'), findsNothing);
    });
  });
}
