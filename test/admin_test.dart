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
      accountNumber: '8031234567',
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
        name: 'Bola Support',
        email: 'bola@example.com',
        phone: '',
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
        name: 'Chidi Second',
        email: 'chidi@example.com',
        phone: '',
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
        name: 'Bola Support',
        email: 'bola@example.com',
        phone: '',
        role: AdminRole.support,
      );
      expect(app.currentAdmin?.email, 'owner@example.com');
      expect(app.adminRole, AdminRole.owner);
    });

    test('adding an admin grants access to that email', () async {
      final app = await _account();
      final result = await app.addAdmin(
        name: 'Bola Support',
        email: 'Bola@Example.com',
        phone: '08099887766',
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
        name: 'Bola Support',
        email: 'bola@example.com',
        phone: '',
        role: AdminRole.support,
      );
      final again = await app.addAdmin(
        name: 'Bola Again',
        email: 'BOLA@example.com',
        phone: '',
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
        name: 'Chidi Second',
        email: 'chidi@example.com',
        phone: '',
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

    test('every setting survives storage — none is dropped in transit', () {
      // Change every field away from its default, round trip it, and compare
      // the encoded forms. A setting added without a toJson or fromJson entry
      // fails here rather than silently reverting on the next app start.
      const tuned = PlatformSettings(
        savingsAnnualRate: 0.19,
        minLockMonths: 2,
        maxLockMonths: 48,
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
      expect(Finance.savingsInterest(100000, 12), 17000);

      await app.updatePlatformSettings(
        settings.copyWith(savingsAnnualRate: 0.20),
        ['Savings rate: 17% → 20%'],
      );

      expect(Finance.savingsInterest(100000, 12), 20000);
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
        name: 'Bola Support',
        email: 'bola@example.com',
        phone: '',
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
