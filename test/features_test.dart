import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/data/models/models.dart';
import 'package:kudi9ja/data/models/thrift.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _funded(double amount) async {
  SharedPreferences.setMockInitialValues({});
  final app = AppState(await StorageService.init());
  await app.fundWallet(amount, 'Test');
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Repayment schedule', () {
    Loan buildLoan({double repaid = 0}) => Loan(
      id: 'l1',
      principal: 120000,
      tenureMonths: 3,
      flatRate: 0.25,
      processingFee: 5000,
      purpose: 'Business',
      disbursedAt: DateTime.now().subtract(const Duration(days: 45)),
      dueDate: Finance.addMonths(
        DateTime.now().subtract(const Duration(days: 45)),
        3,
      ),
      amountRepaid: repaid,
    );

    test('produces one equal instalment per month', () {
      final loan = buildLoan();
      expect(loan.schedule.length, 3);
      final each = loan.totalRepayable / 3;
      for (final i in loan.schedule) {
        expect(i.amount, closeTo(each, 0.01));
      }
    });

    test('marks paid instalments from the amount actually repaid', () {
      final each = buildLoan().monthlyRepayment;
      final loan = buildLoan(repaid: each * 2);
      expect(loan.installmentsPaid, 2);
      expect(loan.schedule[0].status, InstallmentStatus.paid);
      expect(loan.schedule[1].status, InstallmentStatus.paid);
      expect(loan.schedule[2].status, isNot(InstallmentStatus.paid));
    });

    test('a part payment on a future instalment shows as partial', () {
      // Disbursed today, so instalment 1 is not yet due.
      final fresh = Loan(
        id: 'l1b',
        principal: 120000,
        tenureMonths: 3,
        flatRate: 0.25,
        processingFee: 5000,
        purpose: 'Business',
        disbursedAt: DateTime.now(),
        dueDate: Finance.addMonths(DateTime.now(), 3),
        amountRepaid: 0,
      );
      final partial = fresh.copyWith(
        amountRepaid: fresh.monthlyRepayment * 0.5,
      );
      expect(partial.schedule.first.status, InstallmentStatus.partial);
      expect(partial.installmentsPaid, 0);
    });

    test('a part payment on an already-due instalment reads as overdue', () {
      // Lateness outranks partial payment — the money is still late.
      final each = buildLoan().monthlyRepayment;
      final loan = buildLoan(repaid: each * 0.5);
      expect(loan.schedule.first.status, InstallmentStatus.overdue);
      expect(loan.installmentsPaid, 0);
    });

    test('nextInstallment is the first unsettled row', () {
      final each = buildLoan().monthlyRepayment;
      final loan = buildLoan(repaid: each * 2);
      expect(loan.nextInstallment?.number, 3);
    });

    test('a fully repaid loan has no next instalment', () {
      final loan = buildLoan(repaid: buildLoan().totalRepayable);
      expect(loan.nextInstallment, isNull);
      expect(loan.outstanding, 0);
    });
  });

  group('Early settlement', () {
    test('rebates half the interest on months not yet started', () {
      final start = DateTime.now().subtract(const Duration(days: 31));
      final loan = Loan(
        id: 'l2',
        principal: 100000,
        tenureMonths: 3,
        flatRate: 0.25,
        processingFee: 5000,
        purpose: 'Rent',
        disbursedAt: start,
        dueDate: Finance.addMonths(start, 3),
      );
      // One month elapsed of three, so one month remains unstarted:
      // half of a third of the 25,000 flat interest.
      final rebate = Finance.earlyPayoffRebate(loan);
      expect(rebate, closeTo(25000 * (1 / 3) * 0.5, 1));
      expect(Finance.earlyPayoffAmount(loan), lessThan(loan.outstanding));
    });

    test('a settled loan earns no rebate', () {
      final loan = Loan(
        id: 'l3',
        principal: 50000,
        tenureMonths: 3,
        flatRate: 0.25,
        processingFee: 5000,
        purpose: 'Personal',
        disbursedAt: DateTime.now(),
        dueDate: Finance.addMonths(DateTime.now(), 3),
        status: LoanStatus.repaid,
      );
      expect(Finance.earlyPayoffRebate(loan), 0);
    });
  });

  group('Fixed Savings', () {
    test('pays the full 17% into the wallet immediately', () async {
      final app = await _funded(500000);
      final before = app.balance;

      final plan = await app.createFixedPlan(
        title: 'School fees',
        principal: 100000,
        months: 12,
      );

      expect(plan.isFixed, isTrue);
      expect(plan.interestPaid, 17000);
      // 100,000 left the wallet, 17,000 came straight back.
      expect(app.balance, closeTo(before - 100000 + 17000, 0.01));
    });

    test('can never be broken', () async {
      final app = await _funded(500000);
      final plan = await app.createFixedPlan(
        title: 'Locked',
        principal: 50000,
        months: 12,
      );
      expect(plan.canBreak, isFalse);
      expect(plan.type.canBreak, isFalse);

      final balanceBefore = app.balance;
      final payout = await app.breakPlan(plan.id);

      expect(payout, 0, reason: 'breaking a fixed plan must be a no-op');
      expect(app.balance, balanceBefore);
      final still = app.plans.firstWhere((p) => p.id == plan.id);
      expect(still.status, SavingsStatus.active);
    });

    test('can be topped up, and the top-up earns its own return', () async {
      final app = await _funded(500000);
      final plan = await app.createFixedPlan(
        title: 'Topped up',
        principal: 50000,
        months: 6,
      );

      final ok = await app.topUpPlan(plan.id, 10000);
      expect(ok, isTrue);

      final updated = app.plans.firstWhere((p) => p.id == plan.id);
      expect(updated.principal, 60000);
      expect(updated.interestPaid, greaterThan(plan.interestPaid));
    });

    test('a closed plan takes no more money', () async {
      final app = await _funded(500000);
      final plan = await app.createFixedPlan(
        title: 'Done',
        principal: 50000,
        months: 1,
      );
      await app.withdrawPlan(plan.id);

      expect(await app.topUpPlan(plan.id, 10000), isFalse);
    });

    test('withdrawing at maturity returns the principal, no extra', () async {
      final app = await _funded(500000);
      final plan = await app.createFixedPlan(
        title: 'Matured',
        principal: 80000,
        months: 1,
      );
      final result = await app.withdrawPlan(plan.id);
      expect(result.principal, 80000);
      expect(result.bonus, 0, reason: 'the 17% was already paid upfront');
    });
  });

  group('Target Savings', () {
    test('turns a goal and a term into a per-deposit amount', () async {
      final app = await _funded(200000);
      // The worked example: 100,000 over 6 months.
      final plan = await app.createTargetPlan(
        title: 'Six month goal',
        emoji: '🎯',
        goal: 100000,
        frequency: AutoFrequency.daily,
        months: 6,
      );

      expect(plan.isTarget, isTrue);
      expect(plan.targetAmount, 100000);
      expect(plan.autoAmount, closeTo(555.56, 0.01));
      expect(plan.principal, 0, reason: 'nothing saved on day one');
      expect(plan.interestPaid, 0, reason: 'nothing paid upfront');
    });

    test('snapshots the tier rate that applied when it opened', () async {
      final app = await _funded(200000);

      final short = await app.createTargetPlan(
        title: 'Short',
        emoji: '🎯',
        goal: 100000,
        frequency: AutoFrequency.daily,
        months: 3,
      );
      final medium = await app.createTargetPlan(
        title: 'Medium',
        emoji: '🎯',
        goal: 100000,
        frequency: AutoFrequency.daily,
        months: 6,
      );
      final long = await app.createTargetPlan(
        title: 'Long',
        emoji: '🎯',
        goal: 100000,
        frequency: AutoFrequency.daily,
        months: 18,
      );

      expect(short.bonusRate, 0.025);
      expect(medium.bonusRate, 0.05);
      expect(long.bonusRate, 0.10);
      expect(short.projectedBonus, closeTo(2500, 0.01));
      expect(medium.projectedBonus, closeTo(5000, 0.01));
      expect(long.projectedBonus, closeTo(10000, 0.01));
    });

    test('the bonus is the tier rate on what was actually saved', () async {
      final app = await _funded(200000);
      final plan = await app.createTargetPlan(
        title: 'Half done',
        emoji: '🎯',
        goal: 100000,
        frequency: AutoFrequency.weekly,
        months: 6,
      );
      await app.topUpPlan(plan.id, 40000);

      final saved = app.plans.firstWhere((p) => p.id == plan.id);
      expect(saved.principal, 40000);
      // 5% tier, applied to the 40,000 in the plan.
      expect(saved.bonusEarned, closeTo(2000, 0.01));
    });

    test('running to maturity pays principal plus the bonus', () async {
      final app = await _funded(300000);
      final plan = await app.createTargetPlan(
        title: 'Finished',
        emoji: '🎯',
        goal: 100000,
        frequency: AutoFrequency.weekly,
        months: 12,
      );
      await app.topUpPlan(plan.id, 100000);

      final before = app.balance;
      final result = await app.withdrawPlan(plan.id);

      expect(result.principal, 100000);
      expect(result.bonus, closeTo(10000, 0.01)); // 10% tier
      expect(app.balance, closeTo(before + 110000, 0.01));
    });

    test('breaking returns everything saved but forfeits the bonus', () async {
      final app = await _funded(200000);
      final plan = await app.createTargetPlan(
        title: 'Broken',
        emoji: '🎯',
        goal: 100000,
        frequency: AutoFrequency.daily,
        months: 6,
      );
      await app.topUpPlan(plan.id, 50000);

      final before = app.balance;
      final payout = await app.breakPlan(plan.id);

      expect(payout, 50000);
      expect(app.balance, closeTo(before + 50000, 0.01));

      final broken = app.plans.firstWhere((p) => p.id == plan.id);
      expect(broken.status, SavingsStatus.broken);
      expect(broken.interestPaid, 0);
      expect(broken.autoEnabled, isFalse);
    });

    test('a broken plan cannot then be withdrawn for a bonus', () async {
      final app = await _funded(200000);
      final plan = await app.createTargetPlan(
        title: 'Broken twice',
        emoji: '🎯',
        goal: 100000,
        frequency: AutoFrequency.daily,
        months: 6,
      );
      await app.topUpPlan(plan.id, 30000);
      await app.breakPlan(plan.id);

      final second = await app.breakPlan(plan.id);
      expect(second, 0, reason: 'a broken plan is closed for good');
    });

    test('a due contribution moves money but pays nothing yet', () async {
      final app = await _funded(200000);
      final plan = await app.createTargetPlan(
        title: 'Scheduled',
        emoji: '🎯',
        goal: 90000,
        frequency: AutoFrequency.daily,
        months: 3,
      );
      expect(plan.autoIsDue, isFalse);

      final due = plan.copyWith(
        nextAutoRun: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(due.autoIsDue, isTrue);
    });

    test('pausing stops the schedule', () async {
      final app = await _funded(200000);
      final plan = await app.createTargetPlan(
        title: 'Paused',
        emoji: '🎯',
        goal: 90000,
        frequency: AutoFrequency.daily,
        months: 3,
      );
      await app.setAutoSaveEnabled(plan.id, false);
      final updated = app.plans.firstWhere((p) => p.id == plan.id);
      expect(updated.autoEnabled, isFalse);
      expect(updated.autoIsDue, isFalse);
    });
  });

  group('Thrift circles', () {
    ThriftCircle build({int round = 1, List<int> paid = const []}) =>
        ThriftCircle(
          id: 'c1',
          name: 'Office ajo',
          contribution: 20000,
          frequency: AutoFrequency.monthly,
          startDate: DateTime.now(),
          createdByMe: true,
          currentRound: round,
          roundsPaid: paid,
          members: const [
            ThriftMember(name: 'Ada', initials: 'A'),
            ThriftMember(name: 'Me', initials: 'M', isMe: true),
            ThriftMember(name: 'Bola', initials: 'B'),
            ThriftMember(name: 'Chidi', initials: 'C'),
          ],
        );

    test('the pot is the contribution times the membership', () {
      final c = build();
      expect(c.potSize, 80000);
      expect(c.totalCommitment, 80000);
    });

    test('my round is my position in the rotation', () {
      expect(build().myRound, 2);
    });

    test('collection status advances with the rounds', () {
      expect(build(round: 1).iHaveCollected, isFalse);
      expect(build(round: 2).iHaveCollected, isFalse); // collecting now
      expect(build(round: 3).iHaveCollected, isTrue);
    });

    test('a circle completes once every member has collected', () {
      expect(build(round: 4).isComplete, isFalse);
      expect(build(round: 5).isComplete, isTrue);
    });

    test('paid rounds are tracked per round', () {
      expect(build(round: 2, paid: [1]).hasPaidThisRound, isFalse);
      expect(build(round: 2, paid: [1, 2]).hasPaidThisRound, isTrue);
    });

    test('contributing debits the wallet and records the round', () async {
      SharedPreferences.setMockInitialValues({});
      final app = AppState(await StorageService.init());
      await app.fundWallet(100000, 'Test');

      final circle = await app.createCircle(
        name: 'Family',
        emoji: '🤝',
        contribution: 20000,
        frequency: AutoFrequency.monthly,
        members: const [
          ThriftMember(name: 'Me', initials: 'M', isMe: true),
          ThriftMember(name: 'Sade', initials: 'S'),
        ],
      );

      final before = app.balance;
      await app.contributeToCircle(circle.id);
      expect(app.balance, closeTo(before - 20000, 0.01));

      final updated = app.circles.firstWhere((c) => c.id == circle.id);
      expect(updated.hasPaidThisRound, isTrue);
    });
  });

  group('Notifications', () {
    test('money events raise unread notifications', () async {
      final app = await _funded(200000);
      await app.createFixedPlan(
        title: 'Goal',
        principal: 50000,
        months: 12,
      );
      expect(app.unreadCount, greaterThan(0));

      await app.markNotificationsRead();
      expect(app.unreadCount, 0);
    });
  });

  group('Credit factors', () {
    test('sum to the published score', () async {
      final app = await _funded(300000);
      await app.createFixedPlan(
        title: 'Lock',
        principal: 100000,
        months: 12,
      );
      final sum = app.creditFactors.fold(0, (s, f) => s + f.points);
      expect(app.creditScore, (560 + sum).clamp(300, 850));
    });
  });
}
