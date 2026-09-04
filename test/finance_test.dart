import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/core/constants/app_config.dart';
import 'package:kudi9ja/data/models/models.dart';
import 'package:kudi9ja/data/models/platform_settings.dart';

void main() {
  group('Savings — 17% paid upfront', () {
    test('one year on 100k pays exactly 17,000', () {
      expect(Finance.savingsInterest(100000, 12), 17000);
    });

    test('the one-month minimum still pays a pro-rated return', () {
      expect(Finance.savingsInterest(120000, 1), closeTo(1700, 0.001));
    });

    test('the five-year maximum pays 85% of principal', () {
      expect(Finance.savingsInterest(100000, 60), closeTo(85000, 0.001));
      expect(Finance.effectiveYieldPct(60), closeTo(85, 0.001));
    });

    test('a savings month is 30 days, so 6 months is 180', () {
      expect(Finance.targetDays(3), 90);
      expect(Finance.targetDays(6), 180);
      expect(Finance.targetDays(12), 360);
    });

    test('splits a goal into the right daily amount', () {
      // The worked example: 100,000 over 6 months daily.
      final perDay = Finance.targetPerDeposit(
        100000,
        AutoFrequency.daily,
        6,
      );
      expect(perDay, closeTo(555.56, 0.01));
      // The deposits add back up to the goal.
      final runs = Finance.targetRuns(AutoFrequency.daily, 6);
      expect(runs, 180);
      expect(perDay * runs, closeTo(100000, 0.01));
    });

    test('splits a goal into the right weekly amount', () {
      final runs = Finance.targetRuns(AutoFrequency.weekly, 6);
      expect(runs, 25); // 180 days / 7, whole weeks only
      final perWeek = Finance.targetPerDeposit(
        100000,
        AutoFrequency.weekly,
        6,
      );
      expect(perWeek, closeTo(4000, 0.01));
      expect(perWeek * runs, closeTo(100000, 0.01));
    });

    test('the bonus rate steps up with the term', () {
      expect(Finance.targetRateFor(3), 0.025);
      expect(Finance.targetRateFor(5), 0.025);
      expect(Finance.targetRateFor(6), 0.05);
      expect(Finance.targetRateFor(11), 0.05);
      expect(Finance.targetRateFor(12), 0.10);
      expect(Finance.targetRateFor(60), 0.10);
    });

    test('the published tier rates are 2.5, 5 and 10 percent', () {
      expect(AppConfig.targetRateShort, 0.025);
      expect(AppConfig.targetRateMedium, 0.05);
      expect(AppConfig.targetRateLong, 0.10);
      expect(AppConfig.targetTierMedium, 6);
      expect(AppConfig.targetTierLong, 12);
    });

    test('bonus is the tier rate applied to what was saved', () {
      expect(Finance.targetBonus(100000, 3), closeTo(2500, 0.001));
      expect(Finance.targetBonus(100000, 6), closeTo(5000, 0.001));
      expect(Finance.targetBonus(100000, 12), closeTo(10000, 0.001));
      expect(Finance.targetBonus(100000, 24), closeTo(10000, 0.001));
    });

    test('Target Savings runs for at least 3 months', () {
      expect(AppConfig.minTargetMonths, 3);
    });

    test('lock bounds match the product rules', () {
      expect(AppConfig.minLockMonths, 1);
      expect(AppConfig.maxLockMonths, 60);
      expect(AppConfig.savingsAnnualRate, 0.17);
    });
  });

  group('Lending', () {
    test('the ceiling is 5,000,000 naira', () {
      expect(AppConfig.maxLoanAmount, 5000000);
    });

    test('the management fee reaches its 1% band inside the loan range', () {
      // The threshold must sit under the ceiling, or the percentage band is
      // unreachable and the rule is decorative.
      expect(
        settings.processingFeeThreshold,
        lessThan(settings.maxLoanAmount),
      );
      expect(Finance.processingFee(settings.maxLoanAmount), 50000);
    });

    test('tenures run from 1 month to 2 years', () {
      expect(AppConfig.maxLoanTenureMonths, 24);
      expect(settings.loanTenures.first, 1);
      expect(settings.loanTenures.last, 24);
      expect(settings.loanTenures, hasLength(24));
    });

    test('every selectable tenure has a rate of its own', () {
      for (final months in settings.loanTenures) {
        expect(
          AppConfig.loanRatesByTenure.containsKey(months),
          isTrue,
          reason: 'no published rate for a $months-month loan',
        );
        expect(settings.loanRateFor(months), greaterThan(0));
      }
    });

    test('the shipped card never makes a longer loan cheaper per month', () {
      // Two rules hold the card together. If an edit breaks either, a
      // customer can be better off picking a tenure they do not want.
      var previousTotal = 0.0;
      var previousPerMonth = double.infinity;

      for (final months in settings.loanTenures) {
        final total = settings.loanRatePctFor(months);
        final perMonth = total / months;

        expect(
          total,
          greaterThan(previousTotal),
          reason: 'the total must rise with the tenure, but $months months '
              'costs no more than ${months - 1}',
        );
        expect(
          perMonth,
          lessThan(previousPerMonth),
          reason: 'the cost per month must fall with the tenure, but '
              '$months months costs more per month than ${months - 1}',
        );

        previousTotal = total;
        previousPerMonth = perMonth;
      }
    });

    test('the published rate card starts at 12.5%, 17% and 25%', () {
      expect(settings.loanRateFor(1), 0.125);
      expect(settings.loanRateFor(2), 0.17);
      expect(settings.loanRateFor(3), 0.25);
    });

    test('a rate with a half point is never rounded away for display', () {
      expect(settings.loanRateLabelFor(1), '12.5%');
      expect(settings.loanRateLabelFor(2), '17%');
      expect(settings.loanRateLabelFor(3), '25%');
      expect(settings.loanRateRange, '12.5-134%');
    });

    test('interest is a flat charge at the rate for the tenure', () {
      expect(Finance.loanInterest(200000, 1), closeTo(25000, 0.001));
      expect(Finance.loanInterest(200000, 2), closeTo(34000, 0.001));
      expect(Finance.loanInterest(200000, 3), closeTo(50000, 0.001));
    });

    test('a longer tenure costs more in total, never less', () {
      var previous = 0.0;
      for (final months in settings.loanTenures) {
        final total = Finance.loanTotal(200000, months);
        expect(total, greaterThan(previous), reason: '$months months');
        previous = total;
      }
      expect(Finance.loanTotal(200000, 1), closeTo(225000, 0.001));
      expect(Finance.loanTotal(200000, 2), closeTo(234000, 0.001));
      expect(Finance.loanTotal(200000, 3), closeTo(250000, 0.001));
    });

    test('the rate does not vary with the amount borrowed', () {
      for (final principal in [50000.0, 200000.0, 500000.0]) {
        expect(
          Finance.loanInterest(principal, 2) / principal,
          closeTo(0.17, 0.000001),
          reason: 'only the tenure may move the rate',
        );
      }
    });

    test('a tenure with no rate of its own falls back, never to zero', () {
      final sparse = settings.copyWith(
        loanRates: const {1: 0.10, 6: 0.40},
      );
      expect(sparse.loanRateFor(1), 0.10);
      // 3 has no entry, so it takes the nearest shorter tenure that does.
      expect(sparse.loanRateFor(3), 0.10);
      expect(sparse.loanRateFor(6), 0.40);
      // Past the end of the table, the longest defined tenure holds.
      expect(sparse.loanRateFor(24), 0.40);
      // Below the start of it, the shortest does.
      expect(sparse.loanRateFor(0), 0.10);
    });

    test('an admin can reprice any single tenure without touching others', () {
      final next = settings.withLoanRate(7, 0.42);
      expect(next.loanRateFor(7), 0.42);
      expect(next.loanRateFor(6), settings.loanRateFor(6));
      expect(next.loanRateFor(8), settings.loanRateFor(8));
      expect(next.sameLoanRatesAs(settings), isFalse);
      expect(settings.loanRateFor(7), isNot(0.42));
    });

    test('the rate table survives a round trip through storage', () {
      final tuned = settings.withLoanRate(17, 0.93);
      final restored = PlatformSettings.fromJson(tuned.toJson());
      expect(restored.sameLoanRatesAs(tuned), isTrue);
      expect(restored.loanRateFor(17), 0.93);
      expect(restored.loanRateFor(24), tuned.loanRateFor(24));
    });

    test('settings saved before the table existed still load', () {
      // The three-tier shape that preceded the table.
      final legacy = PlatformSettings.fromJson({
        'loanRate1Month': 0.11,
        'loanRate2Months': 0.16,
        'loanRate3Months': 0.24,
      });
      expect(legacy.loanRateFor(1), 0.11);
      expect(legacy.loanRateFor(2), 0.16);
      expect(legacy.loanRateFor(3), 0.24);
      // Tenures the old settings never knew about keep the shipped rates.
      expect(legacy.loanRateFor(12), AppConfig.loanRatesByTenure[12]);

      // And the single flat rate that preceded even that.
      final flat = PlatformSettings.fromJson({'loanFlatRate': 0.25});
      expect(flat.loanRateFor(1), 0.25);
      expect(flat.loanRateFor(3), 0.25);
    });

    test('instalments split the total repayable evenly', () {
      expect(Finance.loanMonthly(200000, 1), closeTo(225000, 0.01));
      expect(Finance.loanMonthly(200000, 2), closeTo(117000, 0.01));
      expect(Finance.loanMonthly(200000, 3), closeTo(83333.33, 0.01));
    });

    test('the floor is 50,000 naira', () {
      expect(AppConfig.minLoanAmount, 50000);
    });
  });

  group('Processing fee', () {
    test('is a flat 5,000 at the minimum loan', () {
      expect(Finance.processingFee(50000), 5000);
      expect(Finance.netDisbursed(50000), 45000);
    });

    test('stays flat across the whole 50k-500k band', () {
      for (final amount in [50000.0, 120000.0, 250000.0, 499999.0]) {
        expect(
          Finance.processingFee(amount),
          5000,
          reason: 'fee should be flat at $amount',
        );
      }
    });

    test('is 5,000 at the 500,000 threshold under either rule', () {
      // The flat fee and the 1% rule agree exactly here, so the curve
      // is continuous — no jump at the boundary.
      expect(Finance.processingFee(500000), 5000);
      expect(500000 * AppConfig.loanProcessingFeeRate, 5000);
      expect(Finance.netDisbursed(500000), 495000);
    });

    test('switches to 1% the moment the threshold is passed', () {
      // 500,001 is already above it — there is no grace band.
      expect(Finance.processingFee(500001), closeTo(5000.01, 0.0001));
      expect(Finance.processingFee(600000), 6000);
      expect(Finance.processingFee(1000000), 10000);
      expect(Finance.netDisbursed(1000000), 990000);
    });

    test('the 1% is of the whole amount, never of the excess', () {
      // The excess reading would make a 1,000,000 loan cost 5,000 — half of
      // what it actually costs — so this is worth pinning down.
      expect(Finance.processingFee(1000000), 10000);
      expect(
        Finance.processingFee(1000000),
        isNot(closeTo((1000000 - 500000) * 0.01, 0.01)),
      );
    });

    test('the fee is continuous across the threshold', () {
      final below = Finance.processingFee(500000);
      final above = Finance.processingFee(500000.01);
      expect(above - below, lessThan(1));
      expect(above, greaterThanOrEqualTo(below));
    });

    test('never exceeds 1% of the loan', () {
      for (final amount in [50000.0, 500000.0, 750000.0, 2000000.0]) {
        expect(Finance.processingFee(amount), lessThanOrEqualTo(amount * 0.1));
      }
    });

    test('Finance and the settings charge the same fee, always', () {
      // The admin panel prices an unsaved draft through the settings; a
      // customer is priced through Finance. If these ever diverge, the
      // preview lies about what will be charged.
      for (final amount in [50000.0, 499999.0, 500000.0, 500001.0, 900000.0]) {
        expect(
          settings.processingFeeFor(amount),
          Finance.processingFee(amount),
          reason: 'fee disagreement at $amount',
        );
        expect(settings.netDisbursedFor(amount), Finance.netDisbursed(amount));
      }
    });

    test('an admin can move the fee, and the rule keeps its shape', () {
      final tuned = settings.copyWith(
        flatProcessingFee: 7500,
        processingFeeThreshold: 1000000,
        loanProcessingFeeRate: 0.015,
      );

      // Flat up to and including the new threshold...
      expect(tuned.processingFeeFor(50000), 7500);
      expect(tuned.processingFeeFor(999999), 7500);
      expect(tuned.processingFeeFor(1000000), 7500);
      // ...then the new rate, on the whole amount.
      expect(tuned.processingFeeFor(1000001), closeTo(15000.015, 0.001));
      expect(tuned.processingFeeFor(2000000), 30000);

      // The live settings are untouched by a draft.
      expect(settings.processingFeeFor(50000), 5000);
    });

    test('the fee survives a round trip through storage', () {
      final tuned = settings.copyWith(
        flatProcessingFee: 6000,
        processingFeeThreshold: 750000,
        loanProcessingFeeRate: 0.012,
      );
      final restored = PlatformSettings.fromJson(tuned.toJson());
      expect(restored.flatProcessingFee, 6000);
      expect(restored.processingFeeThreshold, 750000);
      expect(restored.loanProcessingFeeRate, 0.012);
      expect(restored.processingFeeFor(800000), closeTo(9600, 0.001));
    });

    test('is deducted from the disbursement, not added to what is owed', () {
      const principal = 200000.0;
      // The fee reduces what lands in the wallet...
      expect(Finance.netDisbursed(principal), 195000);
      // ...but repayment is still calculated on the full principal.
      expect(Finance.loanTotal(principal, 3), closeTo(250000, 0.01));
    });
  });

  group('addMonths', () {
    test('rolls over the year boundary', () {
      expect(
        Finance.addMonths(DateTime(2026, 11, 15), 3),
        DateTime(2027, 2, 15),
      );
    });

    test('clamps to the last day of a shorter month', () {
      expect(
        Finance.addMonths(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 28),
      );
    });

    test('handles the full five-year lock', () {
      expect(
        Finance.addMonths(DateTime(2026, 9, 1), 60),
        DateTime(2031, 9, 1),
      );
    });
  });

  group('Loan model', () {
    test('outstanding falls to zero once fully repaid', () {
      final loan = Loan(
        id: 'l1',
        principal: 100000,
        tenureMonths: 3,
        flatRate: 0.25,
        processingFee: 5000,
        purpose: 'Business',
        disbursedAt: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 4, 1),
      );
      expect(loan.totalRepayable, closeTo(125000, 0.001));

      final settled = loan.copyWith(amountRepaid: loan.totalRepayable);
      expect(settled.outstanding, 0);
      expect(settled.repaymentProgress, 1.0);
    });
  });

  group('SavingsPlan model', () {
    test('total value is principal plus the interest already paid', () {
      final now = DateTime.now();
      final plan = SavingsPlan(
        id: 'p1',
        title: 'Rent',
        principal: 300000,
        lockMonths: 12,
        interestPaid: Finance.savingsInterest(300000, 12),
        startDate: now,
        maturityDate: Finance.addMonths(now, 12),
      );
      expect(plan.interestPaid, closeTo(51000, 0.001));
      expect(plan.totalValue, closeTo(351000, 0.001));
      expect(plan.isMature, isFalse);
      expect(plan.progress, lessThan(0.01));
    });
  });
}
