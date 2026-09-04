import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/data/models/admin.dart';
import 'package:kudi9ja/data/models/models.dart';
import 'package:kudi9ja/data/models/platform_settings.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

AppUser _user({String email = 'owner@example.com', String name = 'Ada Owner'}) =>
    AppUser(
      id: _uuid.v4(),
      fullName: name,
      email: email,
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

Future<AppState> _account({String email = 'owner@example.com'}) async {
  SharedPreferences.setMockInitialValues({});
  applySettings(const PlatformSettings()); // reset the global between tests
  final app = AppState(await StorageService.init());
  await app.createAccount(
    user: _user(email: email),
    password: 'Str0ng!pass',
    signInPasscode: '918273',
    transactionPin: '4917',
  );
  return app;
}

/// A signed-up account for the owner to pick from when granting access.
CustomerRecord _candidate(String fullName, String email) => CustomerRecord(
  id: email,
  fullName: fullName,
  email: email,
  phone: '',
  accountNumber: 'K9-TEST01',
  joinedAt: DateTime(2026, 1, 1),
  balance: 0,
  totalSaved: 0,
  totalOwed: 0,
  interestPaid: 0,
  creditScore: 600,
  plansCount: 0,
  loansCount: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Access control', () {
    test('the first account on a device becomes the owner', () async {
      final app = await _account();
      expect(app.isAdmin, isTrue);
      expect(app.adminRole, AdminRole.owner);
      expect(app.admins.length, 1);
      expect(app.admins.first.addedBy, contains('first account'));
    });

    test('a suspended admin loses the panel and can be reinstated', () async {
      final app = await _account();
      await app.addAdmin(
        customer: _candidate('Bola Support', 'bola@example.com'),
        role: AdminRole.support,
      );
      final bola = app.admins.firstWhere((a) => a.email == 'bola@example.com');

      await app.setAdminActive(bola.id, false);
      expect(
        app.admins.firstWhere((a) => a.id == bola.id).active,
        isFalse,
      );

      await app.setAdminActive(bola.id, true);
      expect(app.admins.firstWhere((a) => a.id == bola.id).active, isTrue);
    });

    test('an admin cannot suspend or remove themselves', () async {
      final app = await _account();
      // A second owner exists, so the last-owner guard is not what blocks it.
      await app.addAdmin(
        customer: _candidate('Chidi Second', 'chidi@example.com'),
        role: AdminRole.owner,
      );
      final me = app.currentAdmin!;

      await app.setAdminActive(me.id, false);
      expect(app.isAdmin, isTrue, reason: 'self-suspension must be refused');

      final removal = await app.removeAdmin(me.id);
      expect(removal.ok, isFalse);
      expect(app.isAdmin, isTrue);
    });

    test('access is matched on the signed-in email, not the record', () async {
      final app = await _account(email: 'owner@example.com');
      // Someone else on the team does not make this account them.
      await app.addAdmin(
        customer: _candidate('Bola Support', 'bola@example.com'),
        role: AdminRole.support,
      );
      expect(app.currentAdmin?.email, 'owner@example.com');
      expect(app.adminRole, AdminRole.owner);
    });

    test('adding an admin grants access to that email', () async {
      final app = await _account();
      final result = await app.addAdmin(
        customer: _candidate('Bola Support', 'Bola@Example.com'),
        role: AdminRole.support,
      );
      expect(result.ok, isTrue);
      expect(app.admins.length, 2);
      // Emails are normalised, so casing never blocks access.
      expect(
        app.admins.any((a) => a.email == 'bola@example.com'),
        isTrue,
      );
    });

    test('the same email cannot be added twice', () async {
      final app = await _account();
      await app.addAdmin(
        customer: _candidate('Bola Support', 'bola@example.com'),
        role: AdminRole.support,
      );
      final again = await app.addAdmin(
        customer: _candidate('Bola Again', 'BOLA@example.com'),
        role: AdminRole.admin,
      );
      expect(again.ok, isFalse);
      expect(app.admins.length, 2);
    });

    test('the sole owner cannot remove themselves', () async {
      final app = await _account();
      final result = await app.removeAdmin(app.admins.first.id);
      expect(result.ok, isFalse);
      expect(app.isAdmin, isTrue, reason: 'the panel must stay reachable');
    });

    test('an owner can remove another owner', () async {
      final app = await _account();
      await app.addAdmin(
        customer: _candidate('Chidi Second', 'chidi@example.com'),
        role: AdminRole.owner,
      );
      final target = app.admins.firstWhere(
        (a) => a.email == 'chidi@example.com',
      );
      final result = await app.removeAdmin(target.id);
      expect(result.ok, isTrue);
      expect(app.admins.length, 1);
      expect(app.adminRole, AdminRole.owner);
    });

    test('an admin cannot demote themselves out of the panel', () async {
      final app = await _account();
      await app.changeAdminRole(app.currentAdmin!.id, AdminRole.viewer);
      expect(app.adminRole, AdminRole.owner);
      expect(app.isAdmin, isTrue);
    });
  });

  group('Role permissions', () {
    test('only an owner manages the team', () {
      expect(AdminRole.owner.canManageTeam, isTrue);
      expect(AdminRole.admin.canManageTeam, isFalse);
      expect(AdminRole.support.canManageTeam, isFalse);
      expect(AdminRole.viewer.canManageTeam, isFalse);
    });

    test('owners and admins can change rates', () {
      expect(AdminRole.owner.canEditSettings, isTrue);
      expect(AdminRole.admin.canEditSettings, isTrue);
      expect(AdminRole.support.canEditSettings, isFalse);
      expect(AdminRole.viewer.canEditSettings, isFalse);
    });

    test('viewers cannot act on loans', () {
      expect(AdminRole.viewer.canActOnLoans, isFalse);
      expect(AdminRole.support.canActOnLoans, isTrue);
    });
  });

  group('Platform settings', () {
    test('default to the compiled-in product rules', () {
      applySettings(const PlatformSettings());
      expect(settings.savingsAnnualRate, 0.17);
      expect(settings.targetRateShort, 0.025);
      expect(settings.targetRateMedium, 0.05);
      expect(settings.targetRateLong, 0.10);
      expect(settings.minTargetMonths, 3);
      expect(settings.targetRateFor(4), 0.025);
      expect(settings.targetRateFor(6), 0.05);
      expect(settings.targetRateFor(12), 0.10);
      expect(settings.minLoanAmount, 50000);
      expect(settings.maxLoanAmount, 5000000);
      expect(settings.flatProcessingFee, 5000);
      expect(settings.loanRateFor(3), 0.25);
      expect(settings.maxLoanTenureMonths, 24);
      expect(settings.loanTenures.last, 24);
    });

    test('the role table says exactly what the panel enforces', () {
      // Each capability reads the same getter that gates the screen, so the
      // matrix cannot drift from behaviour. This pins the intended shape.
      const expected = <AdminRole, List<bool>>{
        //                 see  audit  pay  loans  cust  rates  team
        AdminRole.owner:   [true, true, true, true, true, true, true],
        AdminRole.admin:   [true, true, true, true, true, true, false],
        AdminRole.support: [true, true, true, true, true, false, false],
        AdminRole.viewer:  [true, true, false, false, false, false, false],
      };

      expect(kAdminCapabilities, hasLength(7));
      for (final entry in expected.entries) {
        final actual = [
          for (final c in kAdminCapabilities) c.held(entry.key),
        ];
        expect(actual, entry.value, reason: entry.key.label);
      }
    });

    test('access is granted to an account, never to a typed address', () async {
      final app = await _account();

      // The owner picks somebody who has signed up; the email is what
      // membership is keyed on, and the name comes off their account.
      final result = await app.addAdmin(
        customer: _candidate('Bola Support', 'BOLA@Example.com '),
        role: AdminRole.support,
      );

      expect(result.ok, isTrue);
      final added = app.admins.firstWhere((a) => a.role == AdminRole.support);
      expect(added.email, 'bola@example.com', reason: 'normalised');
      expect(added.name, 'Bola Support');

      // The same address cannot be granted access twice.
      final again = await app.addAdmin(
        customer: _candidate('Bola Again', 'bola@example.com'),
        role: AdminRole.admin,
      );
      expect(again.ok, isFalse);
      expect(again.message, contains('already has panel access'));
    });

    test('an account with no email cannot be granted the panel', () async {
      final app = await _account();
      final result = await app.addAdmin(
        customer: _candidate('No Email', ''),
        role: AdminRole.support,
      );
      expect(result.ok, isFalse);
      expect(app.admins.any((a) => a.name == 'No Email'), isFalse);
    });

    test('the savings rate is spread evenly across the year, by day', () {
      // 17% a year, pro-rated by day: 1 year is the full rate, 2 years is
      // double it, 30 days is a twelfth of a year's worth.
      const p = 100000.0;
      expect(Finance.effectiveYieldPct(365), closeTo(17.0, 0.001));
      expect(Finance.effectiveYieldPct(730), closeTo(34.0, 0.001));
      expect(Finance.effectiveYieldPct(1825), closeTo(85.0, 0.001));

      // The short end, to one decimal as a customer would read it.
      expect(Finance.effectiveYieldPct(30), closeTo(1.4, 0.05));
      expect(Finance.effectiveYieldPct(60), closeTo(2.8, 0.05));
      expect(Finance.effectiveYieldPct(90), closeTo(4.2, 0.05));

      // Every extra day is worth exactly one day's interest, at any length.
      final perDay = Finance.savingsInterest(p, 1);
      for (final days in [31, 173, 400, 1000]) {
        expect(
          Finance.savingsInterest(p, days) - Finance.savingsInterest(p, days - 1),
          closeTo(perDay, 0.0001),
          reason: 'day $days should add exactly one day of interest',
        );
      }
    });

    test('only an owner may touch the team', () {
      for (final role in AdminRole.values) {
        expect(role.canManageTeam, role == AdminRole.owner, reason: role.label);
      }
    });

    test('a viewer can look, and change nothing', () {
      const viewer = AdminRole.viewer;
      expect(viewer.canViewCustomers, isTrue);
      expect(viewer.canViewAudit, isTrue);
      expect(viewer.canApprovePayments, isFalse);
      expect(viewer.canActOnLoans, isFalse);
      expect(viewer.canManageCustomers, isFalse);
      expect(viewer.canEditSettings, isFalse);
      expect(viewer.canManageTeam, isFalse);
    });

    test('support moves money but cannot reprice the product', () {
      const support = AdminRole.support;
      expect(support.canApprovePayments, isTrue);
      expect(support.canEditSettings, isFalse);
    });

    test('every setting survives storage — none is dropped in transit', () {
      // Change every field away from its default, round trip it, and compare
      // the encoded forms. A setting added without a toJson or fromJson entry
      // fails here rather than silently reverting on the next app start.
      const tuned = PlatformSettings(
        savingsAnnualRate: 0.19,
        minLockDays: 45,
        maxLockDays: 1500,
        daysPerYear: 360,
        minSavingsAmount: 7500,
        maxSavingsAmount: 90000000,
        targetRateShort: 0.03,
        targetRateMedium: 0.06,
        targetRateLong: 0.11,
        minTargetMonths: 4,
        targetTierMedium: 5,
        targetTierLong: 11,
        daysPerSavingsMonth: 31,
        minLoanAmount: 60000,
        maxLoanAmount: 6000000,
        loanRates: {1: 0.13, 2: 0.18, 3: 0.26},
        maxLoanTenureMonths: 18,
        flatProcessingFee: 6000,
        processingFeeThreshold: 750000,
        loanProcessingFeeRate: 0.012,
        earlyPayoffRebateShare: 0.4,
        loanBaseCap: 150000,
        loanSavingsMultiple: 1.75,
        loanScoreBaseline: 520,
        loanScorePerPoint: 450,
        loanOfferRounding: 2500,
        creditBaseScore: 570,
        creditPointsPerPlan: 20,
        creditPlanPointsCap: 95,
        creditNairaPerSavingsPoint: 30000,
        creditSavingsPointsCap: 110,
        creditPointsPerRepaidLoan: 35,
        creditRepaidPointsCap: 130,
        creditOverduePenalty: 80,
        creditVerifiedBonus: 45,
        creditScoreFloor: 320,
        creditScoreCeiling: 860,
        maxPasscodeAttempts: 4,
        lockTimeoutMinutes: 5,
        minDepositAmount: 250,
        minWithdrawalAmount: 750,
        minCircleContribution: 2500,
        minCircleMembers: 3,
        maxCircleMembers: 20,
        otpResendSeconds: 60,
        dailyTransferLimit: 2000000,
        welcomeBonus: 3000,
        savingsEnabled: false,
        lendingEnabled: false,
        thriftEnabled: false,
        maintenanceMode: true,
        companyAccountName: 'Test Ltd',
        companyAccountNumber: '0000000000',
        companyBank: 'Test Bank',
      );

      final restored = PlatformSettings.fromJson(tuned.toJson());
      expect(restored.toJson(), tuned.toJson());

      // And nothing came back as a compiled-in default by accident.
      const shipped = PlatformSettings();
      for (final key in tuned.toJson().keys) {
        expect(
          restored.toJson()[key],
          isNot(shipped.toJson()[key]),
          reason: '$key looks like it fell back to the default',
        );
      }
    });

    test('a rate change flows straight into the finance engine', () async {
      final app = await _account();
      expect(Finance.savingsInterest(100000, 365), closeTo(17000, 0.001));

      await app.updatePlatformSettings(
        settings.copyWith(savingsAnnualRate: 0.20),
        ['Savings rate: 17% → 20%'],
      );

      expect(Finance.savingsInterest(100000, 365), closeTo(20000, 0.001));
      expect(settings.savingsRatePct, 20);
    });

    test('a fee change flows into new loans', () async {
      final app = await _account();
      expect(Finance.processingFee(100000), 5000);

      await app.updatePlatformSettings(
        settings.copyWith(flatProcessingFee: 7500),
        ['Flat fee: 5,000 → 7,500'],
      );

      expect(Finance.processingFee(100000), 7500);
      expect(Finance.netDisbursed(100000), 92500);
    });

    test('settings survive a reload from storage', () async {
      SharedPreferences.setMockInitialValues({});
      applySettings(const PlatformSettings());
      final store = await StorageService.init();
      final app = AppState(store);
      await app.createAccount(
        user: _user(),
        password: 'Str0ng!pass',
        signInPasscode: '918273',
        transactionPin: '4917',
      );
      await app.updatePlatformSettings(
        settings.withLoanRate(3, 0.30),
        ['Loan rate 3m: 25% → 30%'],
      );

      // A fresh controller over the same store rehydrates the change.
      applySettings(const PlatformSettings());
      AppState(store);
      expect(settings.loanRateFor(3), 0.30);
    });

    test('existing loans keep the terms they were opened on', () async {
      final app = await _account();
      await app.fundWallet(600000, 'Test');
      final loan = await app.requestLoan(
        principal: 100000,
        months: 3,
        purpose: 'Business',
      );
      final agreedTotal = loan.totalRepayable;
      expect(agreedTotal, closeTo(125000, 0.01));

      await app.updatePlatformSettings(
        settings.withLoanRate(3, 0.40),
        ['Loan rate 3m: 25% → 40%'],
      );

      final stored = app.loans.firstWhere((l) => l.id == loan.id);
      expect(stored.flatRate, 0.25);
      expect(stored.totalRepayable, agreedTotal);
    });
  });

  group('Audit log', () {
    test('records team and settings changes with the actor', () async {
      final app = await _account();
      final before = app.auditLog.length;

      await app.addAdmin(
        customer: _candidate('Bola Support', 'bola@example.com'),
        role: AdminRole.support,
      );
      await app.updatePlatformSettings(
        settings.copyWith(savingsAnnualRate: 0.18),
        ['Savings rate: 17% → 18%'],
      );

      expect(app.auditLog.length, greaterThan(before));
      expect(
        app.auditLog.any((e) => e.category == AuditCategory.team),
        isTrue,
      );
      expect(
        app.auditLog.any((e) => e.category == AuditCategory.settings),
        isTrue,
      );
      expect(app.auditLog.first.actor, 'Ada Owner');
    });
  });

  group('Customer view', () {
    test('the device account appears first and is labelled', () async {
      final app = await _account();
      final me = app.customers.first;
      expect(me.isThisDevice, isTrue);
      expect(me.isSample, isFalse);
      expect(me.fullName, 'Ada Owner');
      expect(me.bvn, '22112233445');
    });

    test('every other row is flagged as sample data', () async {
      final app = await _account();
      final others = app.customers.skip(1);
      expect(others, isNotEmpty);
      expect(others.every((c) => c.isSample), isTrue);
    });

    test('metrics aggregate the whole visible book', () async {
      final app = await _account();
      final m = app.platformMetrics;
      expect(m.customers, app.customers.length);
      expect(
        m.saved,
        app.customers.fold(0.0, (s, c) => s + c.totalSaved),
      );
    });
  });
}
