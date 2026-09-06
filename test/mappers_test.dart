import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/core/theme/app_colors.dart';
import 'package:kudi9ja/data/api/mappers.dart';
import 'package:kudi9ja/data/models/app_notification.dart';
import 'package:kudi9ja/data/models/deposit.dart';
import 'package:kudi9ja/data/models/models.dart';
import 'package:kudi9ja/data/models/withdrawal.dart';

/// Reading the server's JSON.
///
/// The failures this guards against are quiet ones. A mis-mapped enum does not
/// throw — it produces a plausible wrong answer, so a written-off loan shows as
/// pending and a reversed transaction shows as successful. That is the kind of
/// bug that reaches a customer's balance before anybody notices, which is why
/// every state the server can send is pinned here by name.
void main() {
  group('Enum names', () {
    /// The server writes SCREAMING_SNAKE, the app writes camelCase. Getting
    /// this wrong silently mislabels every transaction in the ledger.
    test('transaction kinds map across the naming conventions', () {
      expect(transactionFromApi({'kind': 'SAVINGS_LOCK'}).kind, TxKind.savingsLock);
      expect(transactionFromApi({'kind': 'INTEREST_PAYOUT'}).kind, TxKind.interestPayout);
      expect(transactionFromApi({'kind': 'LOAN_DISBURSEMENT'}).kind, TxKind.loanDisbursement);
      expect(transactionFromApi({'kind': 'LOAN_REPAYMENT'}).kind, TxKind.loanRepayment);
      expect(transactionFromApi({'kind': 'SAVINGS_RELEASE'}).kind, TxKind.savingsRelease);
      expect(transactionFromApi({'kind': 'DEPOSIT'}).kind, TxKind.deposit);
      expect(transactionFromApi({'kind': 'WITHDRAWAL'}).kind, TxKind.withdrawal);
      expect(transactionFromApi({'kind': 'FEE'}).kind, TxKind.fee);
    });

    /// Every state the live server can send, from its OpenAPI schema. If the
    /// server adds one, this test is where it should be noticed.
    test('every loan status the server can send is understood', () {
      const wire = {
        'PENDING': LoanStatus.pending,
        'ACTIVE': LoanStatus.active,
        'REPAID': LoanStatus.repaid,
        'OVERDUE': LoanStatus.overdue,
        'REJECTED': LoanStatus.rejected,
        'CANCELLED': LoanStatus.cancelled,
        'WRITTEN_OFF': LoanStatus.writtenOff,
      };
      wire.forEach((sent, expected) {
        expect(loanFromApi({'status': sent}).status, expected, reason: sent);
      });
    });

    test('every savings status the server can send is understood', () {
      const wire = {
        'ACTIVE': SavingsStatus.active,
        'MATURED': SavingsStatus.matured,
        'WITHDRAWN': SavingsStatus.withdrawn,
        'BROKEN': SavingsStatus.broken,
        'RELEASED_ON_COMPASSIONATE_GROUNDS':
            SavingsStatus.releasedOnCompassionateGrounds,
      };
      wire.forEach((sent, expected) {
        expect(planFromApi({'status': sent}).status, expected, reason: sent);
      });
    });

    test('claim, withdrawal and notification states map', () {
      expect(claimFromApi({'status': 'CONFIRMED'}).status, DepositStatus.confirmed);
      expect(claimFromApi({'purpose': 'LOAN_REPAYMENT'}).purpose,
          DepositPurpose.loanRepayment);
      expect(withdrawalFromApi({'status': 'DECLINED'}).status,
          WithdrawalStatus.declined);
      expect(notificationFromApi({'kind': 'REPAYMENT_DUE'}).kind,
          NotifyKind.repaymentDue);
      expect(notificationFromApi({'kind': 'AUTO_SAVE'}).kind, NotifyKind.autoSave);
    });

    test('theme mode round-trips', () {
      expect(themeModeFromApi('DARK'), AppThemeMode.dark);
      expect(themeModeFromApi('SYSTEM'), AppThemeMode.system);
      expect(themeModeToApi(AppThemeMode.light), 'LIGHT');
    });
  });

  group('Unknown values', () {
    /// A server that grows a new state must not crash an app in somebody's
    /// pocket. It degrades to something safe instead.
    test('an unrecognised status falls back rather than throwing', () {
      expect(loanFromApi({'status': 'SOMETHING_NEW'}).status, LoanStatus.pending);
      expect(planFromApi({'status': 'SOMETHING_NEW'}).status, SavingsStatus.active);
      expect(notificationFromApi({'kind': 'SOMETHING_NEW'}).kind, NotifyKind.general);
    });

    /// The one place the fallback is deliberately pessimistic. Showing an
    /// unsettled payment as settled is how a customer spends money twice.
    test('an unknown transaction status is pending, not successful', () {
      expect(transactionFromApi({'status': 'SOMETHING_NEW'}).status, TxStatus.pending);
      expect(transactionFromApi({}).status, TxStatus.pending);
    });
  });

  group('Missing and malformed fields', () {
    test('an empty object produces a usable record, not an exception', () {
      expect(() => transactionFromApi({}), returnsNormally);
      expect(() => loanFromApi({}), returnsNormally);
      expect(() => planFromApi({}), returnsNormally);
      expect(() => userFromApi({}), returnsNormally);
      expect(() => circleFromApi({}), returnsNormally);
      expect(() => notificationFromApi({}), returnsNormally);
    });

    test('money arrives as a number or a string', () {
      expect(transactionFromApi({'amount': 1500}).amount, 1500.0);
      expect(transactionFromApi({'amount': 1500.50}).amount, 1500.50);
      expect(transactionFromApi({'amount': '1500.50'}).amount, 1500.50);
      expect(transactionFromApi({'amount': null}).amount, 0.0);
    });

    test('an unreadable date does not lose the record', () {
      final tx = transactionFromApi({'amount': 900, 'occurredAt': 'not a date'});
      expect(tx.amount, 900.0, reason: 'the amount still matters');
      expect(tx.date, isNotNull);
    });

    /// A loan under review has been requested but not disbursed. Dating it now
    /// would make a week-old application look like it was approved today.
    test('a pending loan dates from its request, not from now', () {
      final requested = DateTime.now().subtract(const Duration(days: 7));
      final loan = loanFromApi({
        'status': 'PENDING',
        'principal': 200000,
        'requestedAt': requested.toIso8601String(),
        'disbursedAt': null,
        'dueDate': null,
      });

      expect(loan.status, LoanStatus.pending);
      expect(
        loan.disbursedAt.difference(requested).inMinutes.abs(),
        lessThan(1),
      );
    });
  });

  group('What the server owns', () {
    /// The reference is what an admin matches a bank statement against. A
    /// locally derived one would not be found.
    test('the customer reference comes from the server, not from the id', () {
      final user = userFromApi({
        'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'customerRef': 'K9-ZZ9999',
      });
      expect(user.customerRef, 'K9-ZZ9999');
    });

    test('without one, it falls back to the derived form', () {
      final user = userFromApi({'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'});
      expect(user.customerRef, 'K9-AAAAAA');
    });

    /// The server returns four digits and never the whole number. The app must
    /// not present those four as though they were the full BVN.
    test('BVN and NIN arrive as their last four digits only', () {
      final user = userFromApi({'bvnLast4': '4321', 'ninLast4': '8765'});
      expect(user.bvn, '4321');
      expect(user.nin, '8765');
    });

    test('wallet totals are read from the server, not recomputed', () {
      final wallet = WalletSnapshot.fromApi({
        'balance': 125000.75,
        'totalSaved': 500000,
        'totalOwed': 90000,
        'netWorth': 625000.75,
        'totalInterestEarned': 42500,
        'pendingWithdrawals': 15000,
        'customerRef': 'K9-A1B2C3',
      });

      expect(wallet.balance, 125000.75);
      expect(wallet.netWorth, 625000.75);
      expect(wallet.pendingWithdrawals, 15000.0);
      expect(wallet.customerRef, 'K9-A1B2C3');
    });
  });

  group('Terminal states are not open', () {
    /// A written-off loan must not sit in the customer's list of things to
    /// repay, nor be added into what they owe — even though the debt itself has
    /// not been forgiven.
    test('a written-off loan is closed', () {
      final loan = loanFromApi({'status': 'WRITTEN_OFF', 'principal': 300000});
      expect(loan.isOpen, isFalse);
      expect(loan.status.label, 'Written off');
    });

    test('a cancelled loan is closed', () {
      expect(loanFromApi({'status': 'CANCELLED'}).isOpen, isFalse);
    });

    /// Released early by an administrator is not the same as broken by the
    /// customer: one carries a forfeited bonus, the other does not.
    test('a compassionately released plan is distinct from a broken one', () {
      final released =
          planFromApi({'status': 'RELEASED_ON_COMPASSIONATE_GROUNDS'});
      expect(released.status, isNot(SavingsStatus.broken));
      expect(released.status.label, 'Released early');
      expect(released.isOpen, isFalse);
    });
  });

  group('Paging', () {
    test('reads a page envelope', () {
      final page = Page.fromApi({
        'content': [
          {'id': '1', 'amount': 100},
          {'id': '2', 'amount': 200},
        ],
        'page': 2,
        'size': 25,
        'totalElements': 213,
        'totalPages': 9,
      }, transactionFromApi);

      expect(page.items, hasLength(2));
      expect(page.totalElements, 213);
      expect(page.hasMore, isTrue);
    });

    test('the last page reports no more', () {
      final page = Page.fromApi(
          {'content': [], 'page': 8, 'size': 25, 'totalElements': 213, 'totalPages': 9},
          transactionFromApi);
      expect(page.hasMore, isFalse);
    });

    /// Some endpoints return a plain list. Treating that as an empty page would
    /// show a customer nothing at all.
    test('a bare list is treated as a single complete page', () {
      final page = Page.fromApi([
        {'id': '1', 'amount': 100},
      ], transactionFromApi);

      expect(page.items, hasLength(1));
      expect(page.hasMore, isFalse);
      expect(page.totalElements, 1);
    });
  });
}
