import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/core/constants/app_config.dart';
import 'package:kudi9ja/data/models/deposit.dart';
import 'package:kudi9ja/data/models/models.dart';
import 'package:kudi9ja/data/models/platform_settings.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

AppUser _user() => AppUser(
  id: _uuid.v4(),
  fullName: 'Ada Owner',
  email: 'owner@example.com',
  phone: '08031234567',
  dateOfBirth: DateTime(1995, 4, 12),
  gender: 'Female',
  bvn: '22112233445',
  nin: '70112233445',
  address: '1 Test Road',
  state: 'Lagos',
  payoutBank: 'GTBank',
      payoutAccountNumber: '0123456789',
  createdAt: DateTime.now(),
);

Future<AppState> _account({double funding = 0}) async {
  SharedPreferences.setMockInitialValues({});
  applySettings(const PlatformSettings());
  final app = AppState(await StorageService.init());
  await app.createAccount(
    user: _user(),
    password: 'Str0ng!pass',
    signInPasscode: '918273',
    transactionPin: '4917',
  );
  if (funding > 0) await app.fundWallet(funding, 'Test');
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Collection account', () {
    test('defaults to the company Zenith account', () {
      applySettings(const PlatformSettings());
      expect(settings.companyAccountName, 'Quadrilateral Technologies Ltd');
      expect(settings.companyAccountNumber, '1018548852');
      expect(settings.companyBank, 'Zenith Bank');
      expect(AppConfig.companyAccountNumber, '1018548852');
    });

    test('an admin can change it and it persists', () async {
      final app = await _account();
      await app.updatePlatformSettings(
        settings.copyWith(
          companyAccountNumber: '2233445566',
          companyBank: 'GTBank',
        ),
        ['Collection account: 1018548852 → 2233445566'],
      );
      expect(settings.companyAccountNumber, '2233445566');
      expect(settings.companyBank, 'GTBank');
      // The name was untouched.
      expect(settings.companyAccountName, 'Quadrilateral Technologies Ltd');
    });

    test('every pay-in gets its own reference, carrying the customer code', () async {
      final app = await _account();

      final refs = <String>{
        for (var i = 0; i < 200; i++) app.newPaymentReference(),
      };

      // K9-A1B2C3-7F4K — the customer, then this one payment.
      for (final ref in refs) {
        expect(ref, matches(RegExp(r'^K9-[0-9A-F]{6}-[A-Z2-9]{4}$')));
        expect(
          ref.startsWith(app.user!.customerRef),
          isTrue,
          reason: 'an admin must be able to find the customer from the '
              'narration alone',
        );
        // The reference is never the customer's own bank account.
        expect(ref, isNot(contains(app.user!.payoutAccountNumber)));
      }

      // Two payments of the same amount on the same day must be tellable
      // apart on a bank statement, so references may not repeat.
      expect(refs.length, greaterThan(190), reason: 'references collided');
    });

    test('the reference on a claim is the one the customer was shown', () async {
      final app = await _account();
      final shown = app.newPaymentReference();

      final claim = await app.submitDepositClaim(
        amount: 25000,
        purpose: DepositPurpose.wallet,
        reference: shown,
        receiptPath: '/tmp/receipt.png',
      );

      expect(claim.reference, shown);
      expect(app.deposits.first.reference, shown);
    });
  });

  group('The only way money gets in', () {
    test('bank transfer is the only route, and it always needs approval', () {
      // The method chooser offered Card and USSD, and Card credited the
      // wallet on the spot with no claim and no admin. Both are gone.
      expect(
        File('lib/features/wallet/fund_wallet_screen.dart').existsSync(),
        isFalse,
      );

      for (final path in const [
        'lib/features/dashboard/dashboard_screen.dart',
        'lib/features/wallet/wallet_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('FundWalletScreen'),
          isFalse,
          reason: '$path still routes to the old chooser',
        );
        expect(source.contains('PayInScreen'), isTrue, reason: path);
      }

      final payIn = File('lib/features/wallet/pay_in_screen.dart')
          .readAsStringSync();
      // The payment methods themselves, not any word containing "card"
      // (CompanyAccountCard and KCard are widgets).
      for (final gone in const ["'Card'", 'USSD', 'credit_card', 'qr_code']) {
        expect(payIn.contains(gone), isFalse, reason: 'found $gone');
      }
      // A receipt is required before the claim can be submitted.
      expect(payIn.contains('_receipt.isNotEmpty'), isTrue);
    });

    test('a new account starts at zero — nothing is given away', () async {
      final app = await _account();

      // There was a N2,000 welcome bonus credited on sign-up. It is gone:
      // money only enters a wallet through a confirmed bank transfer.
      expect(app.balance, 0);
      expect(app.transactions, isEmpty);

      final source = File('lib/state/app_state.dart').readAsStringSync();
      expect(source.contains('welcomeBonus'), isFalse);
      expect(source.contains('Welcome bonus'), isFalse);

      final settingsSource =
          File('lib/data/models/platform_settings.dart').readAsStringSync();
      expect(settingsSource.contains('welcomeBonus'), isFalse);
    });

    test('a receipt is carried on the claim, for the admin to check', () async {
      final app = await _account();
      final claim = await app.submitDepositClaim(
        amount: 40000,
        purpose: DepositPurpose.wallet,
        reference: app.newPaymentReference(),
        receiptPath: '/tmp/receipt.png',
      );

      expect(claim.hasReceipt, isTrue);
      expect(claim.receiptPath, '/tmp/receipt.png');
      expect(app.deposits.first.receiptPath, '/tmp/receipt.png');
    });

    test("a customer's pay-ins are reachable from their admin record", () async {
      final app = await _account();
      await app.submitDepositClaim(
        amount: 40000,
        purpose: DepositPurpose.wallet,
        reference: app.newPaymentReference(),
        receiptPath: '/tmp/receipt.png',
      );

      final me = app.customers.firstWhere((c) => c.isThisDevice);
      final claims = app.depositsFor(me);
      expect(claims, hasLength(1));
      expect(claims.first.amount, 40000);
      expect(claims.first.status, DepositStatus.pending);
    });
  });

  group('Wallet funding by transfer', () {
    test('a claim credits nothing until it is confirmed', () async {
      final app = await _account();
      final before = app.balance;

      final claim = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 50000,
        purpose: DepositPurpose.wallet,
        receiptPath: '/tmp/receipt.png',
      );

      // The customer's word alone moves no money.
      expect(app.balance, before);
      expect(claim.status, DepositStatus.pending);
      expect(claim.hasReceipt, isTrue);
      expect(app.pendingDepositCount, 1);
      expect(app.pendingDepositValue, 50000);
    });

    test('confirming credits the wallet', () async {
      final app = await _account();
      final before = app.balance;

      final claim = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 50000,
        purpose: DepositPurpose.wallet,
        receiptPath: '/tmp/receipt.png',
      );
      await app.confirmDeposit(claim.id);

      expect(app.balance, closeTo(before + 50000, 0.01));
      expect(app.pendingDepositCount, 0);

      final settled = app.deposits.firstWhere((d) => d.id == claim.id);
      expect(settled.status, DepositStatus.confirmed);
      expect(settled.reviewedBy, 'Ada Owner');
    });

    test('rejecting leaves the balance untouched', () async {
      final app = await _account();
      final before = app.balance;

      final claim = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 50000,
        purpose: DepositPurpose.wallet,
        receiptPath: '/tmp/receipt.png',
      );
      await app.rejectDeposit(claim.id, 'No matching credit');

      // Nothing was credited, so nothing needs reversing.
      expect(app.balance, before);

      final rejected = app.deposits.firstWhere((d) => d.id == claim.id);
      expect(rejected.status, DepositStatus.rejected);
      expect(rejected.note, 'No matching credit');
    });

    test('a decision cannot be applied twice', () async {
      final app = await _account();
      final claim = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 20000,
        purpose: DepositPurpose.wallet,
        receiptPath: '/tmp/r.png',
      );

      await app.confirmDeposit(claim.id);
      final settled = app.balance;

      await app.confirmDeposit(claim.id);
      await app.rejectDeposit(claim.id, 'too late');

      expect(app.balance, settled);
      expect(
        app.deposits.firstWhere((d) => d.id == claim.id).status,
        DepositStatus.confirmed,
      );
    });
  });

  group('Loan repayment by transfer', () {
    Future<(AppState, Loan)> withLoan() async {
      final app = await _account(funding: 200000);
      final loan = await app.requestLoan(
        principal: 100000,
        months: 3,
        purpose: 'Business',
      );
      return (app, loan);
    }

    test('a claim does not touch the loan until confirmed', () async {
      final (app, loan) = await withLoan();
      final owedBefore = loan.outstanding;

      final claim = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 40000,
        purpose: DepositPurpose.loanRepayment,
        receiptPath: '/tmp/receipt.png',
        loanId: loan.id,
        loanPurpose: loan.purpose,
      );

      expect(claim.isLoanRepayment, isTrue);
      expect(
        app.loans.firstWhere((l) => l.id == loan.id).outstanding,
        owedBefore,
      );
    });

    test('confirming applies it to the loan, not the wallet', () async {
      final (app, loan) = await withLoan();
      final walletBefore = app.balance;
      final owedBefore = loan.outstanding;

      final claim = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 40000,
        purpose: DepositPurpose.loanRepayment,
        receiptPath: '/tmp/receipt.png',
        loanId: loan.id,
        loanPurpose: loan.purpose,
      );
      await app.confirmDeposit(claim.id);

      // Credited in and paid straight out, so the wallet nets to zero change.
      expect(app.balance, closeTo(walletBefore, 0.01));
      expect(
        app.loans.firstWhere((l) => l.id == loan.id).outstanding,
        closeTo(owedBefore - 40000, 0.01),
      );
    });

    test('paying the full balance settles the loan', () async {
      final (app, loan) = await withLoan();

      final claim = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: loan.outstanding,
        purpose: DepositPurpose.loanRepayment,
        receiptPath: '/tmp/receipt.png',
        loanId: loan.id,
        loanPurpose: loan.purpose,
      );
      await app.confirmDeposit(claim.id);

      final settled = app.loans.firstWhere((l) => l.id == loan.id);
      expect(settled.outstanding, 0);
      expect(settled.status, LoanStatus.repaid);
    });

    test('rejecting leaves the loan exactly as it was', () async {
      final (app, loan) = await withLoan();
      final owedBefore = loan.outstanding;
      final walletBefore = app.balance;

      final claim = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 40000,
        purpose: DepositPurpose.loanRepayment,
        receiptPath: '/tmp/receipt.png',
        loanId: loan.id,
        loanPurpose: loan.purpose,
      );
      await app.rejectDeposit(claim.id, 'Receipt unreadable');

      expect(app.balance, walletBefore);
      expect(
        app.loans.firstWhere((l) => l.id == loan.id).outstanding,
        owedBefore,
      );
    });
  });

  group('Audit and notifications', () {
    test('both decisions are logged with a reason', () async {
      final app = await _account();
      final a = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 10000,
        purpose: DepositPurpose.wallet,
        receiptPath: '/tmp/a.png',
      );
      final b = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 20000,
        purpose: DepositPurpose.wallet,
        receiptPath: '/tmp/b.png',
      );

      await app.confirmDeposit(a.id);
      await app.rejectDeposit(b.id, 'Duplicate receipt');

      final actions = app.auditLog.map((e) => e.action).toList();
      expect(actions, contains('Payment confirmed'));
      expect(actions, contains('Payment rejected'));
      expect(
        app.auditLog.any((e) => e.detail.contains('Duplicate receipt')),
        isTrue,
      );
    });

    test('the customer is told at submission and at decision', () async {
      final app = await _account();
      final claim = await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 10000,
        purpose: DepositPurpose.wallet,
        receiptPath: '/tmp/a.png',
      );
      await app.confirmDeposit(claim.id);

      final titles = app.notifications.map((n) => n.title).toList();
      expect(titles, contains('Payment submitted'));
      expect(titles, contains('Payment confirmed'));
    });
  });

  group('Pending payment counters', () {
    test('count both directions together', () async {
      final app = await _account(funding: 100000);

      await app.submitDepositClaim(
        reference: app.newPaymentReference(),
        amount: 10000,
        purpose: DepositPurpose.wallet,
        receiptPath: '/tmp/a.png',
      );
      await app.requestWithdrawal(5000, 'GTBank', '0123456789');

      expect(app.pendingDepositCount, 1);
      expect(app.pendingWithdrawalCount, 1);
      expect(app.pendingPaymentCount, 2);
    });
  });
}
