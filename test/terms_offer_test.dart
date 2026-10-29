import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/data/api/mappers.dart';
import 'package:kudi9ja/data/models/loan_application.dart';
import 'package:kudi9ja/data/models/models.dart';

/// Changed terms on an application: the admin offers, the customer agrees or
/// turns them down, and the loan is lent on what they agreed to.
void main() {
  group('Reading an offer off the wire', () {
    test('an application with new terms waiting reads as offered', () {
      final a = loanApplicationFromApi({
        'id': 'a1',
        'amount': 200000,
        'tenureMonths': 3,
        'purpose': 'Stock',
        'status': 'OFFERED',
        'statusLabel': 'New terms to answer',
        'submittedAt': '2026-10-29T09:00:00Z',
        'repaymentFrequency': 'MONTHLY',
        'offer': {
          'months': 6,
          'flatRate': 0.3,
          'managementFee': 7500,
          'repaymentFeeRate': 0.025,
          'note': 'Six months suits your income better.',
          'offeredAt': '2026-10-29T10:00:00Z',
        },
      });

      expect(a.status, LoanApplicationStatus.offered);
      expect(a.isOffered, isTrue);
      expect(a.isPending, isFalse);
      expect(a.status.isOpen, isTrue);
      expect(a.hasAgreedTerms, isFalse);
      expect(a.pricedMonths, 6);
      expect(a.offer!.flatRate, 0.3);
      expect(a.offer!.managementFee, 7500);
      expect(a.offer!.repaymentFeeRate, 0.025);
      expect(a.offer!.note, 'Six months suits your income better.');
      // The customer's view never names which admin sent it.
      expect(a.offer!.offeredBy, isEmpty);
    });

    test('agreed terms put it back with the team, priced on them', () {
      final a = loanApplicationFromApi({
        'id': 'a1',
        'amount': 200000,
        'tenureMonths': 3,
        'status': 'PENDING',
        'offer': {
          'months': 6,
          'flatRate': 0.3,
          'managementFee': 7500,
          'repaymentFeeRate': 0.02,
          'offeredAt': '2026-10-29T10:00:00Z',
          'agreedAt': '2026-10-29T11:00:00Z',
        },
      });
      expect(a.isPending, isTrue);
      expect(a.hasAgreedTerms, isTrue);
      expect(a.pricedMonths, 6);
    });

    test('the queue row says so without carrying the offer', () {
      final a = loanApplicationFromApi({
        'id': 'a1',
        'status': 'PENDING',
        'termsChanged': true,
        'termsAgreed': true,
      });
      expect(a.offer, isNull);
      expect(a.hasAgreedTerms, isTrue);
    });

    test('terms turned down close the application', () {
      final a = loanApplicationFromApi({'id': 'a1', 'status': 'TERMS_DECLINED'});
      expect(a.status, LoanApplicationStatus.termsDeclined);
      expect(a.status.isOpen, isFalse);
      expect(a.status.label, 'Terms turned down');
    });

    test('an application priced as asked has no offer', () {
      final a = loanApplicationFromApi({'id': 'a1', 'status': 'PENDING', 'tenureMonths': 3});
      expect(a.offer, isNull);
      expect(a.hasAgreedTerms, isFalse);
      expect(a.pricedMonths, 3);
    });
  });

  group('Statuses as the server spells them', () {
    test('two-word statuses keep their underscore', () {
      expect(LoanApplicationStatus.termsDeclined.wire, 'TERMS_DECLINED');
      expect(LoanApplicationStatus.offered.wire, 'OFFERED');
      expect(LoanApplicationStatus.pending.wire, 'PENDING');
    });

    test('statuses saved on the device before these existed read back the same', () {
      // Stored by index: the old four must keep theirs.
      expect(LoanApplicationStatus.pending.index, 0);
      expect(LoanApplicationStatus.approved.index, 1);
      expect(LoanApplicationStatus.rejected.index, 2);
      expect(LoanApplicationStatus.cancelled.index, 3);
    });

    test('an offer survives being saved on the device', () {
      final a = LoanApplication(
        id: 'a1',
        amount: 200000,
        tenureMonths: 3,
        purpose: 'Stock',
        status: LoanApplicationStatus.offered,
        submittedAt: DateTime(2026, 10, 29),
        offer: TermsOffer(
          months: 6,
          flatRate: 0.3,
          managementFee: 7500,
          repaymentFeeRate: 0.02,
          offeredAt: DateTime(2026, 10, 29, 10),
        ),
      );
      final back = LoanApplication.fromJson(a.toJson());
      expect(back.status, LoanApplicationStatus.offered);
      expect(back.offer!.months, 6);
      expect(back.offer!.flatRate, 0.3);
      expect(back.offer!.agreed, isFalse);
    });
  });

  group('Pricing a loan on changed terms', () {
    test('the offer replaces the rate, both fees and the length', () {
      final p = Finance.loanPreview(
        200000,
        6,
        flatRate: 0.3,
        managementFee: 7500,
        repaymentFeeRate: 0.025,
      );
      expect(p.rate, 0.3);
      expect(p.loanTotal, 260000);
      expect(p.count, 6);
      // 260,000 / 6 rounds up to 43,334; 2.5% of that is 1,083.35, up to 1,084.
      expect(p.base, 43334);
      expect(p.instalmentFee, 1084);
      expect(p.feeRate, 0.025);
      expect(p.fee, 7500);
      expect(p.net, 192500);
    });

    test('a management fee of nothing is honoured, not replaced', () {
      final p = Finance.loanPreview(200000, 3, managementFee: 0);
      expect(p.fee, 0);
      expect(p.net, 200000);
    });

    test('with no offer it prices exactly as before', () {
      final plain = Finance.loanPreview(200000, 3);
      final same = Finance.loanPreview(
        200000,
        3,
        flatRate: plain.rate,
        managementFee: plain.fee,
        repaymentFeeRate: plain.feeRate,
      );
      expect(same.total, plain.total);
      expect(same.net, plain.net);
      expect(same.each, plain.each);
    });
  });

  group('Rates as a customer reads them', () {
    test('whole and fractional percentages, never rounded away', () {
      expect(fractionPct(0.3), '30%');
      expect(fractionPct(0.02), '2%');
      expect(fractionPct(0.025), '2.5%');
      expect(fractionPct(0.0225), '2.25%');
      expect(fractionPct(0.175), '17.5%');
      expect(fractionPct(1), '100%');
      expect(fractionPct(0), '0%');
    });
  });
}
