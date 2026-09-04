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
  accountNumber: '8031234567',
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

    test('the payment reference is tied to the customer account', () async {
      final app = await _account();
      expect(app.paymentReference, 'K9-8031234567');
    });
  });

  group('Wallet funding by transfer', () {
    test('a claim credits nothing until it is confirmed', () async {
      final app = await _account();
      final before = app.balance;

      final claim = await app.submitDepositClaim(
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
        amount: 10000,
        purpose: DepositPurpose.wallet,
        receiptPath: '/tmp/a.png',
      );
      final b = await app.submitDepositClaim(
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
