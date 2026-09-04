import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/data/models/models.dart';
import 'package:kudi9ja/data/models/platform_settings.dart';
import 'package:kudi9ja/data/models/withdrawal.dart';
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

/// An account that is also the device owner, so it can approve payouts.
Future<AppState> _account(double funding) async {
  SharedPreferences.setMockInitialValues({});
  applySettings(const PlatformSettings());
  final app = AppState(await StorageService.init());
  await app.createAccount(
    user: _user(),
    password: 'Str0ng!pass',
    signInPasscode: '918273',
    transactionPin: '4917',
  );
  await app.fundWallet(funding, 'Test');
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Withdrawal requests', () {
    test('debits the wallet immediately and queues for approval', () async {
      final app = await _account(100000);
      final before = app.balance;

      final request = await app.requestWithdrawal(
        30000,
        'GTBank',
        '0123456789',
      );

      // Held straight away, so it cannot be spent twice while under review.
      expect(app.balance, closeTo(before - 30000, 0.01));
      expect(request.status, WithdrawalStatus.pending);
      expect(app.pendingWithdrawalCount, 1);
      expect(app.pendingWithdrawalValue, 30000);
    });

    test('records the transaction as pending, not successful', () async {
      final app = await _account(100000);
      await app.requestWithdrawal(30000, 'GTBank', '0123456789');

      final tx = app.transactions.firstWhere(
        (t) => t.kind == TxKind.withdrawal,
      );
      expect(tx.status, TxStatus.pending);
      expect(tx.isPending, isTrue);
    });

    test('approving settles it without moving money again', () async {
      final app = await _account(100000);
      final request = await app.requestWithdrawal(
        30000,
        'GTBank',
        '0123456789',
      );
      final balanceWhilePending = app.balance;

      await app.approveWithdrawal(request.id);

      // The debit already happened; approval must not double-charge.
      expect(app.balance, balanceWhilePending);
      expect(app.pendingWithdrawalCount, 0);

      final settled = app.withdrawals.firstWhere((w) => w.id == request.id);
      expect(settled.status, WithdrawalStatus.approved);
      expect(settled.reviewedBy, 'Ada Owner');
      expect(settled.reviewedAt, isNotNull);

      final tx = app.transactions.firstWhere((t) => t.id == request.id);
      expect(tx.status, TxStatus.successful);
    });

    test('declining refunds the customer in full', () async {
      final app = await _account(100000);
      final before = app.balance;

      final request = await app.requestWithdrawal(
        30000,
        'GTBank',
        '0123456789',
      );
      expect(app.balance, closeTo(before - 30000, 0.01));

      await app.declineWithdrawal(request.id, 'Account name mismatch');

      // Every naira back.
      expect(app.balance, closeTo(before, 0.01));
      expect(app.pendingWithdrawalCount, 0);

      final declined = app.withdrawals.firstWhere((w) => w.id == request.id);
      expect(declined.status, WithdrawalStatus.declined);
      expect(declined.note, 'Account name mismatch');

      final tx = app.transactions.firstWhere((t) => t.id == request.id);
      expect(tx.status, TxStatus.reversed);
    });

    test('a decision cannot be applied twice', () async {
      final app = await _account(100000);
      final request = await app.requestWithdrawal(
        30000,
        'GTBank',
        '0123456789',
      );

      await app.approveWithdrawal(request.id);
      final settled = app.balance;

      // A second approval, or a late decline, must change nothing.
      await app.approveWithdrawal(request.id);
      await app.declineWithdrawal(request.id, 'too late');

      expect(app.balance, settled);
      expect(
        app.withdrawals.firstWhere((w) => w.id == request.id).status,
        WithdrawalStatus.approved,
      );
    });

    test('every decision is written to the audit log', () async {
      final app = await _account(200000);
      final a = await app.requestWithdrawal(10000, 'GTBank', '0123456789');
      final b = await app.requestWithdrawal(20000, 'Kuda', '9876543210');

      await app.approveWithdrawal(a.id);
      await app.declineWithdrawal(b.id, 'Suspicious activity');

      final actions = app.auditLog.map((e) => e.action).toList();
      expect(actions, contains('Withdrawal approved'));
      expect(actions, contains('Withdrawal declined'));
    });

    test('the customer is notified either way', () async {
      final app = await _account(200000);
      final request = await app.requestWithdrawal(
        15000,
        'GTBank',
        '0123456789',
      );
      await app.approveWithdrawal(request.id);

      final titles = app.notifications.map((n) => n.title).toList();
      expect(titles, contains('Withdrawal submitted'));
      expect(titles, contains('Withdrawal approved'));
    });
  });

  group('Transaction filters', () {
    test('each filter selects only its own kinds', () {
      Transaction tx(TxKind kind) => Transaction(
        id: kind.name,
        kind: kind,
        amount: 1000,
        description: kind.label,
        date: DateTime.now(),
        balanceAfter: 0,
      );

      expect(TxFilter.deposits.matches(tx(TxKind.deposit)), isTrue);
      expect(TxFilter.deposits.matches(tx(TxKind.withdrawal)), isFalse);

      expect(TxFilter.withdrawals.matches(tx(TxKind.withdrawal)), isTrue);
      expect(TxFilter.transfers.matches(tx(TxKind.transfer)), isTrue);
      expect(TxFilter.fees.matches(tx(TxKind.fee)), isTrue);

      // Savings covers locking, interest and release.
      for (final k in [
        TxKind.savingsLock,
        TxKind.interestPayout,
        TxKind.savingsRelease,
      ]) {
        expect(TxFilter.savings.matches(tx(k)), isTrue);
      }
      expect(TxFilter.savings.matches(tx(TxKind.deposit)), isFalse);

      // Loans covers disbursement and repayment.
      for (final k in [TxKind.loanDisbursement, TxKind.loanRepayment]) {
        expect(TxFilter.loans.matches(tx(k)), isTrue);
      }
      expect(TxFilter.loans.matches(tx(TxKind.fee)), isFalse);

      // "All" lets everything through.
      for (final k in TxKind.values) {
        expect(TxFilter.all.matches(tx(k)), isTrue);
      }
    });
  });

  group('Admin customer ledger', () {
    test('the device account returns its real transactions', () async {
      final app = await _account(50000);
      final me = app.customers.first;

      expect(me.isThisDevice, isTrue);
      expect(app.transactionsFor(me), app.transactions);
      expect(app.transactionsFor(me), isNotEmpty);
    });

    test('sample customers return a labelled illustrative ledger', () async {
      final app = await _account(50000);
      final sample = app.customers.firstWhere((c) => c.isSample);

      final ledger = app.transactionsFor(sample);
      expect(ledger, isNotEmpty);
      expect(ledger.every((t) => t.counterparty == 'Sample data'), isTrue);
      // Stable across reads, so the panel does not reshuffle on rebuild.
      expect(app.transactionsFor(sample), same(ledger));
    });

    test('a sample ledger spans several filterable kinds', () async {
      final app = await _account(50000);
      final sample = app.customers.firstWhere(
        (c) => c.isSample && c.loansCount > 0,
      );
      final ledger = app.transactionsFor(sample);

      for (final f in [
        TxFilter.deposits,
        TxFilter.withdrawals,
        TxFilter.savings,
        TxFilter.loans,
      ]) {
        expect(
          ledger.where(f.matches),
          isNotEmpty,
          reason: '${f.label} should have something to show',
        );
      }
    });
  });

  group('Fixed Savings top-up', () {
    test('accepts more money and pays its return upfront', () async {
      final app = await _account(500000);
      final plan = await app.createFixedPlan(
        title: 'School fees',
        principal: 100000,
        days: 365,
      );

      final before = app.balance;
      final ok = await app.topUpPlan(plan.id, 50000);
      expect(ok, isTrue);

      final updated = app.plans.firstWhere((p) => p.id == plan.id);
      expect(updated.principal, 150000);
      // The top-up earned its own interest over the months still to run.
      expect(updated.interestPaid, greaterThan(plan.interestPaid));

      final interest = updated.interestPaid - plan.interestPaid;
      expect(app.balance, closeTo(before - 50000 + interest, 0.01));
    });

    test('is still impossible to break after a top-up', () async {
      final app = await _account(500000);
      final plan = await app.createFixedPlan(
        title: 'Sealed',
        principal: 100000,
        days: 365,
      );
      await app.topUpPlan(plan.id, 25000);

      expect(await app.breakPlan(plan.id), 0);
      expect(
        app.plans.firstWhere((p) => p.id == plan.id).status,
        SavingsStatus.active,
      );
    });
  });
}
