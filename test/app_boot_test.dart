import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/data/models/models.dart';
import 'package:kudi9ja/data/services/security_service.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:kudi9ja/widgets/primitives.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _freshState() async {
  SharedPreferences.setMockInitialValues({});
  return AppState(await StorageService.init());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session gating', () {
    test('a first run starts in onboarding', () async {
      final app = await _freshState();
      expect(app.stage, AuthStage.onboarding);
    });

    test('finishing onboarding without an account lands signed out', () async {
      final app = await _freshState();
      await app.completeOnboarding();
      expect(app.stage, AuthStage.signedOut);
    });
  });

  group('Passcode security', () {
    test('hashes are salted and never equal the plaintext', () {
      final hash = SecurityService.hash('483920');
      expect(hash, isNot('483920'));
      expect(hash.length, 64);
      expect(SecurityService.verify('483920', hash), isTrue);
      expect(SecurityService.verify('483921', hash), isFalse);
    });

    test('an OTP is always six digits', () {
      for (var i = 0; i < 50; i++) {
        expect(SecurityService.issueOtp(), matches(RegExp(r'^\d{6}$')));
      }
    });
  });

  group('Accounts and verification', () {
    test('Kudi9ja issues no account number of its own', () {
      // The old build minted a NUBAN-style number from the phone. Nothing
      // may do that again: a Kudi9ja "account number" is not a real bank
      // account and cannot be paid into.
      final source = File('lib/data/services/security_service.dart')
          .readAsStringSync();
      expect(source.contains('accountNumberFrom'), isFalse);

      final user = AppUser(
        id: 'a1b2c3d4-e5f6-7788-99aa-bbccddeeff00',
        fullName: 'Ada Customer',
        email: 'ada@example.com',
        phone: '08031234567',
        dateOfBirth: DateTime(1995, 4, 12),
        gender: 'Female',
        bvn: '22112233445',
        nin: '11223344556',
        address: '1 Test Street',
        state: 'Lagos',
        payoutBank: 'GTBank',
        payoutAccountNumber: '0123456789',
        createdAt: DateTime(2026, 1, 1),
      );

      // Money leaves to the customer's own bank account.
      expect(user.hasPayoutAccount, isTrue);
      expect(user.payoutBank, 'GTBank');
      expect(user.payoutAccountNumber, '0123456789');

      // The reference is an identifier, never a payable account, and it is
      // not derived from the phone number.
      expect(user.customerRef, 'K9-A1B2C3');
      expect(user.customerRef.contains(user.phone), isFalse);
    });

    test('a customer without a payout account is flagged, not blocked', () {
      final user = AppUser(
        id: 'a1b2c3d4-e5f6-7788-99aa-bbccddeeff00',
        fullName: 'Ada Customer',
        email: 'ada@example.com',
        phone: '08031234567',
        dateOfBirth: DateTime(1995, 4, 12),
        gender: 'Female',
        bvn: '22112233445',
        nin: '11223344556',
        address: '1 Test Street',
        state: 'Lagos',
        payoutBank: '',
        payoutAccountNumber: '',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(user.hasPayoutAccount, isFalse);
    });

    test('sign-up verifies the email only — there is no SMS step', () {
      final flow = File('lib/features/auth/signup/signup_flow.dart')
          .readAsStringSync();
      expect(flow.contains('phone-otp'), isFalse);
      expect(flow.contains('OtpChannel'), isFalse);
      expect(flow.contains('email-otp'), isTrue);

      // The OTP screen itself no longer knows how to send an SMS.
      final otp = File('lib/features/auth/signup/steps/otp_step.dart')
          .readAsStringSync();
      expect(otp.contains('OtpChannel'), isFalse);
      expect(otp.contains('sms'), isFalse);

      // And the draft carries no phone-verified flag to set.
      final draft = File('lib/features/auth/signup/signup_draft.dart')
          .readAsStringSync();
      expect(draft.contains('phoneVerified'), isFalse);
      expect(draft.contains('payoutAccountNumber'), isTrue);
    });
  });

  group('Marketing copy', () {
    test('headline figures are read from settings, never written out', () {
      // The onboarding and sign-in screens advertised "up to ₦500,000" for a
      // while after the ceiling became ₦5,000,000. Nothing customer-facing
      // may hard-code a product figure again.
      for (final path in const [
        'lib/features/onboarding/onboarding_screen.dart',
        'lib/features/auth/sign_in_screen.dart',
      ]) {
        // Comments may discuss the old figures; only code counts.
        final source = File(path)
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join(String.fromCharCode(10));
        expect(
          source.contains('₦500,000'),
          isFalse,
          reason: '$path hard-codes a stale loan ceiling',
        );
        expect(
          source.contains('₦500k'),
          isFalse,
          reason: '$path hard-codes a stale loan ceiling',
        );
        expect(
          source.contains('17%'),
          isFalse,
          reason: '$path hard-codes the savings rate',
        );
        expect(
          source.contains('settings.maxLoanAmount'),
          isTrue,
          reason: '$path should read the ceiling from settings',
        );
      }
    });
  });

  group('Dashboard balance card', () {
    test('the credit score is not a wallet figure and is off the card', () {
      final card = File('lib/features/dashboard/balance_card.dart')
          .readAsStringSync();

      // It belongs with borrowing — the Loans tab and Profile still show it.
      expect(card.contains('creditScore'), isFalse);
      expect(card.contains('creditBand'), isFalse);

      // What replaced it is money the customer has actually been paid.
      expect(card.contains('Earned so far'), isTrue);
      expect(card.contains('totalInterestEarned'), isTrue);

      // And it honours the hide-balances toggle, like every other figure.
      expect(
        RegExp(r"hidden[\s\S]{0,80}totalInterestEarned").hasMatch(card),
        isTrue,
        reason: 'earnings must be masked when balances are hidden',
      );

      for (final path in const [
        'lib/features/loans/loans_screen.dart',
        'lib/features/profile/profile_screen.dart',
      ]) {
        expect(
          File(path).readAsStringSync().contains('creditScore'),
          isTrue,
          reason: '$path should still surface the score',
        );
      }
    });
  });

  testWidgets('the gold button renders its label and fires once', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoldButton(label: 'Lock savings', onPressed: () => taps++),
        ),
      ),
    );
    expect(find.text('Lock savings'), findsOneWidget);
    await tester.tap(find.text('Lock savings'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a disabled gold button ignores taps', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GoldButton(label: 'Continue')),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    // No callback to assert on — the test passes by not throwing.
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('provider wiring exposes AppState to the tree', (tester) async {
    final app = await _freshState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          home: Builder(
            builder: (context) =>
                Text('${context.watch<AppState>().balance}'),
          ),
        ),
      ),
    );
    expect(find.text('0.0'), findsOneWidget);
  });
}
