import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/theme/app_colors.dart';
import '../data/models/admin.dart';
import '../data/models/app_notification.dart';
import '../data/models/deposit.dart';
import '../data/models/models.dart';
import '../data/models/thrift.dart';
import '../data/models/withdrawal.dart';
import '../data/services/security_service.dart';
import '../data/services/storage_service.dart';
import '../data/models/platform_settings.dart';

const _uuid = Uuid();
final _random = Random.secure();

/// One contributor to the credit score, shown on the breakdown screen.
class CreditFactor {
  const CreditFactor({
    required this.label,
    required this.detail,
    required this.points,
    required this.maxPoints,
    this.negative = false,
  });

  final String label;
  final String detail;
  final int points;
  final int maxPoints;
  final bool negative;

  double get fill => maxPoints <= 0 ? 0 : (points / maxPoints).clamp(0.0, 1.0);
  bool get isMaxed => maxPoints > 0 && points >= maxPoints;
}

enum AuthStage {
  /// First run — show onboarding.
  onboarding,

  /// No account on the device.
  signedOut,

  /// Account exists, app is locked behind the sign-in passcode.
  locked,

  /// Fully unlocked.
  unlocked,
}

/// The single controller behind the app: session, wallet, savings and loans.
class AppState extends ChangeNotifier {
  AppState(this._store) {
    _hydrate();
  }

  final StorageService _store;

  AuthStage _stage = AuthStage.onboarding;
  AppUser? _user;
  double _balance = 0;
  List<SavingsPlan> _plans = [];
  List<Loan> _loans = [];
  List<Transaction> _txns = [];
  List<ThriftCircle> _circles = [];
  List<AppNotification> _notifications = [];
  bool _hideBalance = false;
  AppThemeMode _themeMode = AppThemeMode.dark;
  bool _autoDebit = false;
  List<AdminUser> _admins = [];
  List<AuditEntry> _audit = [];
  List<WithdrawalRequest> _withdrawals = [];
  List<DepositClaim> _deposits = [];
  int _failedAttempts = 0;

  // ── Getters ─────────────────────────────────────────────────────────────
  AuthStage get stage => _stage;
  AppUser? get user => _user;
  double get balance => _balance;
  bool get hideBalance => _hideBalance;
  int get failedAttempts => _failedAttempts;
  int get attemptsLeft => settings.maxPasscodeAttempts - _failedAttempts;
  bool get hasAccount => _user != null;
  bool get biometricsEnabled => _user?.biometricsEnabled ?? false;

  List<SavingsPlan> get plans =>
      List.unmodifiable(_plans..sort((a, b) => b.startDate.compareTo(a.startDate)));

  List<SavingsPlan> get activePlans =>
      _plans.where((p) => p.isOpen).toList()
        ..sort((a, b) => a.maturityDate.compareTo(b.maturityDate));

  List<Loan> get loans =>
      List.unmodifiable(_loans..sort((a, b) => b.disbursedAt.compareTo(a.disbursedAt)));

  List<Loan> get activeLoans => _loans.where((l) => l.isOpen).toList();

  List<Transaction> get transactions =>
      List.unmodifiable(_txns..sort((a, b) => b.date.compareTo(a.date)));

  bool get autoDebit => _autoDebit;

  List<ThriftCircle> get circles => List.unmodifiable(_circles);

  List<ThriftCircle> get activeCircles =>
      _circles.where((c) => !c.isComplete).toList();

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications..sort((a, b) => b.date.compareTo(a.date)));

  int get unreadCount => _notifications.where((n) => !n.read).length;

  /// Plans with an auto-save rule currently switched on.
  List<SavingsPlan> get autoSavePlans =>
      _plans.where((p) => p.autoEnabled && p.isOpen).toList();

  /// Total committed to thrift circles that have not finished.
  double get thriftCommitted => activeCircles.fold(
    0.0,
    (sum, c) => sum + c.contribution * c.roundsPaid.length,
  );

  /// The instalment falling due soonest across every open loan.
  ({Loan loan, Installment installment})? get nextRepayment {
    ({Loan loan, Installment installment})? best;
    for (final l in activeLoans) {
      final next = l.nextInstallment;
      if (next == null) continue;
      if (best == null || next.dueDate.isBefore(best.installment.dueDate)) {
        best = (loan: l, installment: next);
      }
    }
    return best;
  }

  /// Instalments due within the next week, across all loans.
  List<({Loan loan, Installment installment})> get upcomingRepayments {
    final out = <({Loan loan, Installment installment})>[];
    for (final l in activeLoans) {
      for (final i in l.schedule) {
        if (i.status == InstallmentStatus.paid) continue;
        if (i.daysUntilDue <= 7) out.add((loan: l, installment: i));
      }
    }
    out.sort((a, b) => a.installment.dueDate.compareTo(b.installment.dueDate));
    return out;
  }

  /// Total principal currently locked away in savings.
  double get totalSaved =>
      activePlans.fold(0.0, (sum, p) => sum + p.principal);

  /// Every naira of 17% interest this user has been paid, ever.
  double get totalInterestEarned =>
      _plans.fold(0.0, (sum, p) => sum + p.interestPaid);

  double get totalOwed => activeLoans.fold(0.0, (sum, l) => sum + l.outstanding);

  /// Wallet + locked savings — the headline net worth figure.
  double get netWorth => _balance + totalSaved;

  /// How much more this user may borrow right now.
  double get loanHeadroom {
    final used = activeLoans.fold(0.0, (s, l) => s + l.principal);
    final left = settings.maxLoanAmount - used;
    return left < 0 ? 0 : left;
  }

  /// A simple, explainable credit score out of 850.
  int get creditScore {
    var score = settings.creditBaseScore;
    score += (_plans.length * settings.creditPointsPerPlan).clamp(
      0,
      settings.creditPlanPointsCap,
    );
    score += (totalSaved / settings.creditNairaPerSavingsPoint)
        .floor()
        .clamp(0, settings.creditSavingsPointsCap);
    final repaid = _loans.where((l) => l.status == LoanStatus.repaid).length;
    score += (repaid * settings.creditPointsPerRepaidLoan).clamp(
      0,
      settings.creditRepaidPointsCap,
    );
    if (_loans.any((l) => l.status == LoanStatus.overdue)) {
      score -= settings.creditOverduePenalty;
    }
    if (_user?.kycTier == KycTier.tier2) score += settings.creditVerifiedBonus;
    return score.clamp(settings.creditScoreFloor, settings.creditScoreCeiling);
  }

  String get creditBand {
    final s = creditScore;
    if (s >= 750) return 'Excellent';
    if (s >= 680) return 'Very good';
    if (s >= 600) return 'Good';
    if (s >= 500) return 'Fair';
    return 'Building';
  }

  // ── Hydration ───────────────────────────────────────────────────────────
  void _hydrate() {
    _user = _store.user;
    _balance = _store.balance;
    _plans = _store.plans;
    _loans = _store.loans;
    _txns = _store.transactions;
    _circles = _store.circles;
    _notifications = _store.notifications;
    _hideBalance = _store.hideBalance;
    // Kudi9ja is gold on black. Light mode is a deliberate choice, not
    // something a phone's setting turns on for a customer who never asked.
    final saved = _store.themeMode;
    _themeMode = saved == null
        ? AppThemeMode.dark
        : AppThemeMode.values[saved.clamp(0, AppThemeMode.values.length - 1)];
    _autoDebit = _store.autoDebit;
    _admins = _store.admins;
    _audit = _store.audit;
    _withdrawals = _store.withdrawals;
    _deposits = _store.deposits;
    applySettings(_store.platformSettings);

    if (!_store.hasSeenOnboarding) {
      _stage = AuthStage.onboarding;
    } else if (_user == null) {
      _stage = AuthStage.signedOut;
    } else {
      _stage = AuthStage.locked;
    }
    _refreshMaturity();
  }

  /// Flips plans past their maturity date so the UI is always truthful.
  void _refreshMaturity() {
    var changed = false;
    for (var i = 0; i < _plans.length; i++) {
      final p = _plans[i];
      if (p.status == SavingsStatus.active && p.isMature) {
        // A matured target plan stops contributing; its bonus is credited
        // when the customer withdraws.
        _plans[i] = p.copyWith(
          status: SavingsStatus.matured,
          autoEnabled: false,
        );
        changed = true;
      }
    }
    for (var i = 0; i < _loans.length; i++) {
      final l = _loans[i];
      if (l.status == LoanStatus.active &&
          DateTime.now().isAfter(l.dueDate) &&
          l.outstanding > 0) {
        _loans[i] = l.copyWith(status: LoanStatus.overdue);
        changed = true;
      }
    }
    if (changed) {
      _store.savePlans(_plans);
      _store.saveLoans(_loans);
    }
  }

  // ── Onboarding & session ────────────────────────────────────────────────
  Future<void> completeOnboarding() async {
    await _store.setSeenOnboarding();
    _stage = hasAccount ? AuthStage.locked : AuthStage.signedOut;
    notifyListeners();
  }

  /// Which palette the customer has chosen.
  AppThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _store.setThemeMode(mode.index);
    notifyListeners();
  }

  Future<void> toggleHideBalance() async {
    _hideBalance = !_hideBalance;
    await _store.setHideBalance(_hideBalance);
    notifyListeners();
  }

  /// Persists a brand-new account at the end of the signup journey.
  Future<void> createAccount({
    required AppUser user,
    required String password,
    required String signInPasscode,
    required String transactionPin,
  }) async {
    _user = user;
    await _store.saveUser(user);
    await _store.savePassword(SecurityService.hash(password));
    await _store.saveSignInPasscode(SecurityService.hash(signInPasscode));
    await _store.saveTxnPin(SecurityService.hash(transactionPin));
    await _store.setSignedIn(true);

    // A new account starts empty. Money only ever enters a wallet through a
    // confirmed bank transfer.
    _balance = 0;
    _plans = [];
    _loans = [];
    _txns = [];

    await _seedOwnerIfNeeded(user);

    _failedAttempts = 0;
    _stage = AuthStage.unlocked;
    notifyListeners();
  }

  /// Email + password sign-in used when returning from a signed-out state.
  bool signInWithPassword(String email, String password) {
    final u = _user;
    if (u == null) return false;
    final emailOk = u.email.toLowerCase() == email.trim().toLowerCase();
    if (emailOk && SecurityService.verify(password, _store.passwordHash)) {
      _store.setSignedIn(true);
      _stage = AuthStage.locked;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// The passcode gate shown every time the app is reopened.
  bool unlock(String passcode) {
    if (SecurityService.verify(passcode, _store.signInPasscodeHash)) {
      _failedAttempts = 0;
      _stage = AuthStage.unlocked;
      _refreshMaturity();
      notifyListeners();
      // Catch the schedule up on anything that fell due while the app was shut.
      unawaited(runDueAutoSaves());
      return true;
    }
    _failedAttempts++;
    if (_failedAttempts >= settings.maxPasscodeAttempts) {
      _stage = AuthStage.signedOut;
      _store.setSignedIn(false);
      _failedAttempts = 0;
    }
    notifyListeners();
    return false;
  }

  void unlockViaBiometrics() {
    _failedAttempts = 0;
    _stage = AuthStage.unlocked;
    _refreshMaturity();
    notifyListeners();
  }

  /// Called whenever the app leaves the foreground.
  void lock() {
    if (_stage == AuthStage.unlocked) {
      _stage = AuthStage.locked;
      notifyListeners();
    }
  }

  /// Drops the session but keeps the account — the user comes back in with
  /// their email and password.
  Future<void> signOut() async {
    await _store.setSignedIn(false);
    _failedAttempts = 0;
    _stage = AuthStage.signedOut;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _store.wipeAccount();
    _user = null;
    _balance = 0;
    _plans = [];
    _loans = [];
    _txns = [];
    _stage = AuthStage.signedOut;
    notifyListeners();
  }

  // ── Credential checks & changes ─────────────────────────────────────────
  bool verifyTransactionPin(String pin) =>
      SecurityService.verify(pin, _store.txnPinHash);

  bool verifySignInPasscode(String code) =>
      SecurityService.verify(code, _store.signInPasscodeHash);

  Future<void> changeSignInPasscode(String next) async {
    await _store.saveSignInPasscode(SecurityService.hash(next));
    notifyListeners();
  }

  Future<void> changeTransactionPin(String next) async {
    await _store.saveTxnPin(SecurityService.hash(next));
    notifyListeners();
  }

  Future<void> setBiometrics(bool on) async {
    final u = _user;
    if (u == null) return;
    _user = u.copyWith(biometricsEnabled: on);
    await _store.saveUser(_user!);
    notifyListeners();
  }

  Future<void> updateProfile({String? phone, String? address, String? state}) async {
    final u = _user;
    if (u == null) return;
    _user = u.copyWith(phone: phone, address: address, state: state);
    await _store.saveUser(_user!);
    notifyListeners();
  }

  // ── Wallet ──────────────────────────────────────────────────────────────
  Future<Transaction> _credit(
    double amount,
    TxKind kind,
    String description, {
    String counterparty = '',
  }) async {
    _balance += amount;
    return _record(amount, kind, description, counterparty: counterparty);
  }

  Future<Transaction> _debit(
    double amount,
    TxKind kind,
    String description, {
    String counterparty = '',
    TxStatus status = TxStatus.successful,
  }) async {
    _balance -= amount;
    return _record(
      amount,
      kind,
      description,
      counterparty: counterparty,
      status: status,
    );
  }

  Future<Transaction> _record(
    double amount,
    TxKind kind,
    String description, {
    String counterparty = '',
    TxStatus status = TxStatus.successful,
  }) async {
    final tx = Transaction(
      id: _uuid.v4(),
      kind: kind,
      amount: amount,
      description: description,
      date: DateTime.now(),
      balanceAfter: _balance,
      reference: SecurityService.reference('K9'),
      counterparty: counterparty,
      status: status,
    );
    _txns.insert(0, tx);
    await _store.saveBalance(_balance);
    await _store.saveTransactions(_txns);
    return tx;
  }

  /// Credits the wallet directly, with no claim and no approval.
  ///
  /// **This is not a customer path.** Money only reaches a wallet when an
  /// admin confirms a deposit claim against the bank statement — see
  /// [submitDepositClaim] and [confirmDeposit]. This exists to seed a wallet
  /// in tests.
  @visibleForTesting
  Future<Transaction> fundWallet(double amount, String source) async {
    final tx = await _credit(
      amount,
      TxKind.deposit,
      'Wallet funded via $source',
      counterparty: source,
    );
    notifyListeners();
    return tx;
  }

  /// Submits a withdrawal for admin approval. The money leaves the wallet
  /// straight away so it cannot be spent twice while the request is in the
  /// queue; declining it refunds the customer in full.
  Future<WithdrawalRequest> requestWithdrawal(
    double amount,
    String bank,
    String accountNumber,
  ) async {
    final tx = await _debit(
      amount,
      TxKind.withdrawal,
      'Withdrawal to $bank - awaiting approval',
      counterparty: maskedTail(accountNumber),
      status: TxStatus.pending,
    );

    final request = WithdrawalRequest(
      id: tx.id,
      customerName: _user?.fullName ?? 'Customer',
      customerAccount: _user?.customerRef ?? '',
      amount: amount,
      bank: bank,
      destinationAccount: accountNumber,
      requestedAt: DateTime.now(),
      reference: tx.reference,
    );

    _withdrawals.insert(0, request);
    await _store.saveWithdrawals(_withdrawals);
    await _notify(
      NotifyKind.general,
      'Withdrawal submitted',
      '${amount.toStringAsFixed(0)} to $bank is with our team for approval. You will be told as soon as it is released.',
      amount: amount,
    );

    notifyListeners();
    return request;
  }

  Future<Transaction> transfer(
    double amount,
    String recipient,
    String note,
  ) async {
    final tx = await _debit(
      amount,
      TxKind.transfer,
      note.isEmpty ? 'Transfer to $recipient' : note,
      counterparty: recipient,
    );
    notifyListeners();
    return tx;
  }

  static String maskedTail(String v) =>
      v.length <= 4 ? v : '******${v.substring(v.length - 4)}';

  // ── Savings ─────────────────────────────────────────────────────────────
  /// **Fixed Savings.** Locks [principal] for [months] and pays the full 17%
  /// return straight into the wallet immediately. The principal cannot be
  /// touched again until maturity — these plans can never be broken.
  Future<SavingsPlan> createFixedPlan({
    required String title,
    required double principal,
    required int days,
    String emoji = '🔒',
  }) async {
    final interest = Finance.savingsInterest(principal, days);
    final now = DateTime.now();
    final plan = SavingsPlan(
      id: _uuid.v4(),
      title: title,
      principal: principal,
      lockDays: days,
      interestPaid: interest,
      startDate: now,
      maturityDate: now.add(Duration(days: days)),
      type: SavingsType.fixed,
      emoji: emoji,
    );

    _plans.insert(0, plan);
    await _store.savePlans(_plans);

    await _debit(principal, TxKind.savingsLock, 'Locked into "$title"');
    await _credit(
      interest,
      TxKind.interestPayout,
      'Upfront ${settings.savingsRatePct.toStringAsFixed(0)}% return on "$title"',
      counterparty: 'Kudi9ja',
    );
    await _notify(
      NotifyKind.interest,
      'Fixed Savings opened',
      'Your ${interest.toStringAsFixed(0)} return is already in your wallet. The principal is locked until ${plan.maturityDate.toIso8601String().split('T').first}.',
      amount: interest,
    );

    notifyListeners();
    return plan;
  }

  /// **Target Savings.** The customer names a [goal] and a term; we work out
  /// what has to go in each day or week and pull it automatically. Nothing is
  /// paid until the final day, when a bonus on everything saved is credited —
  /// 2.5%, 5% or 10% depending on the term. Breaking the plan forfeits it.
  Future<SavingsPlan> createTargetPlan({
    required String title,
    required String emoji,
    required double goal,
    required AutoFrequency frequency,
    required int months,
  }) async {
    final now = DateTime.now();
    final amount = Finance.targetPerDeposit(goal, frequency, months);
    final rate = Finance.targetRateFor(months);
    final maturity = Finance.addMonths(now, months);

    final plan = SavingsPlan(
      id: _uuid.v4(),
      title: title,
      principal: 0,
      // Target terms are chosen in months; the plan still records the real
      // span in days so every screen can speak the same unit.
      lockDays: maturity.difference(now).inDays,
      interestPaid: 0,
      startDate: now,
      maturityDate: maturity,
      type: SavingsType.target,
      targetAmount: goal,
      emoji: emoji,
      autoFrequency: frequency,
      autoAmount: amount,
      nextAutoRun: now.add(frequency.interval),
      autoEnabled: true,
      contributions: 0,
      bonusRate: rate,
    );

    _plans.insert(0, plan);
    await _store.savePlans(_plans);
    await _notify(
      NotifyKind.autoSave,
      'Target Savings started',
      'We will move ${amount.toStringAsFixed(2)} ${frequency.adverb} towards your ${goal.toStringAsFixed(0)} goal. Finish it and you collect a ${(rate * 100).toStringAsFixed(1)}% bonus.',
    );
    notifyListeners();
    return plan;
  }

  Future<void> setAutoSaveEnabled(String planId, bool on) async {
    final i = _plans.indexWhere((p) => p.id == planId);
    if (i < 0) return;
    _plans[i] = _plans[i].copyWith(
      autoEnabled: on,
      nextAutoRun: on
          ? DateTime.now().add(
              _plans[i].autoFrequency?.interval ?? const Duration(days: 1),
            )
          : null,
    );
    await _store.savePlans(_plans);
    notifyListeners();
  }

  /// Runs every Target Savings contribution that has fallen due. Called on
  /// unlock so the schedule catches up whether or not the app was open.
  Future<int> runDueAutoSaves() async {
    var ran = 0;
    for (var i = 0; i < _plans.length; i++) {
      final p = _plans[i];
      if (!p.autoIsDue) continue;

      final amount = p.autoAmount ?? 0;
      if (amount <= 0) continue;

      if (amount > _balance) {
        await _notify(
          NotifyKind.autoSave,
          'Contribution skipped',
          'We could not move ${amount.toStringAsFixed(0)} into "${p.title}" — your wallet was short. We will try again next cycle.',
        );
        _plans[i] = p.copyWith(
          nextAutoRun: DateTime.now().add(p.autoFrequency!.interval),
        );
        continue;
      }

      // Target Savings pays nothing now; the bonus lands on the final day.
      _plans[i] = p.copyWith(
        principal: p.principal + amount,
        contributions: p.contributions + 1,
        nextAutoRun: DateTime.now().add(p.autoFrequency!.interval),
      );

      await _debit(amount, TxKind.savingsLock, 'Saved into "${p.title}"');
      ran++;
    }

    if (ran > 0) {
      await _store.savePlans(_plans);
      notifyListeners();
    }
    return ran;
  }

  /// Manual top-up. Both products accept extra money.
  ///
  /// On **Fixed Savings** the top-up earns its own 17%, pro-rated over the
  /// months still to run, and that interest is paid to the wallet at once —
  /// the same deal as the opening deposit. The extra is locked like the rest.
  ///
  /// On **Target Savings** it simply counts towards the total, and so towards
  /// the bonus at the end.
  Future<bool> topUpPlan(String planId, double amount) async {
    final i = _plans.indexWhere((p) => p.id == planId);
    if (i < 0) return false;
    final p = _plans[i];
    if (!p.isOpen || amount <= 0) return false;

    if (p.isFixed) {
      final daysLeft = _daysLeft(p);
      final interest = Finance.savingsInterest(amount, daysLeft);

      _plans[i] = p.copyWith(
        principal: p.principal + amount,
        interestPaid: p.interestPaid + interest,
        contributions: p.contributions + 1,
      );
      await _store.savePlans(_plans);

      await _debit(amount, TxKind.savingsLock, 'Top-up on "${p.title}"');
      await _credit(
        interest,
        TxKind.interestPayout,
        'Upfront return on top-up to "${p.title}"',
        counterparty: 'Kudi9ja',
      );
      await _notify(
        NotifyKind.interest,
        'Top-up added',
        'Your ${interest.toStringAsFixed(0)} return on this top-up is already in your wallet.',
        amount: interest,
      );
      notifyListeners();
      return true;
    }

    _plans[i] = p.copyWith(
      principal: p.principal + amount,
      contributions: p.contributions + 1,
    );
    await _store.savePlans(_plans);
    await _debit(amount, TxKind.savingsLock, 'Top-up on "${p.title}"');
    notifyListeners();
    return true;
  }

  /// Whole months still to run on a plan, floored at one.
  /// Whole days a plan still has to run. A top-up earns the return for the
  /// time it will actually be locked, not for the plan's original term.
  int _daysLeft(SavingsPlan p) {
    final days = p.maturityDate.difference(DateTime.now()).inDays;
    return days.clamp(0, settings.maxLockDays);
  }

  /// Releases a matured plan. A Fixed plan returns its principal (the 17%
  /// was paid on day one); a Target plan returns the principal plus its 10%
  /// bonus, earned by running to term.
  Future<({double principal, double bonus})> withdrawPlan(String planId) async {
    final i = _plans.indexWhere((p) => p.id == planId);
    if (i < 0) return (principal: 0.0, bonus: 0.0);

    final p = _plans[i];
    final bonus = p.isTarget && !p.bonusPaid ? p.bonusEarned : 0.0;

    _plans[i] = p.copyWith(
      status: SavingsStatus.withdrawn,
      bonusPaid: true,
      interestPaid: p.interestPaid + bonus,
    );
    await _store.savePlans(_plans);

    await _credit(
      p.principal,
      TxKind.savingsRelease,
      'Matured savings released: "${p.title}"',
    );
    if (bonus > 0) {
      await _credit(
        bonus,
        TxKind.interestPayout,
        '${(p.bonusRate * 100).toStringAsFixed(1)}% completion bonus on "${p.title}"',
        counterparty: 'Kudi9ja',
      );
      await _notify(
        NotifyKind.interest,
        'Bonus paid',
        'You finished "${p.title}" and earned ${bonus.toStringAsFixed(0)}.',
        amount: bonus,
      );
    }

    notifyListeners();
    return (principal: p.principal, bonus: bonus);
  }

  /// Breaks a Target Savings plan. Every naira saved comes back, but the 10%
  /// bonus is forfeited in full. Fixed plans cannot be broken and this is a
  /// no-op for them.
  Future<double> breakPlan(String planId) async {
    final i = _plans.indexWhere((p) => p.id == planId);
    if (i < 0) return 0;
    final p = _plans[i];
    if (!p.canBreak) return 0;

    _plans[i] = p.copyWith(status: SavingsStatus.broken, autoEnabled: false);
    await _store.savePlans(_plans);

    await _credit(
      p.principal,
      TxKind.savingsRelease,
      'Broken early: "${p.title}"',
    );
    await _notify(
      NotifyKind.general,
      'Savings broken',
      'Your ${p.principal.toStringAsFixed(0)} is back in your wallet. The ${(p.bonusRate * 100).toStringAsFixed(1)}% bonus was forfeited.',
    );

    notifyListeners();
    return p.principal;
  }

  // ── Loans ───────────────────────────────────────────────────────────────
  Future<Loan> requestLoan({
    required double principal,
    required int months,
    required String purpose,
  }) async {
    final now = DateTime.now();
    final fee = Finance.processingFee(principal);
    final loan = Loan(
      id: _uuid.v4(),
      principal: principal,
      tenureMonths: months,
      flatRate: settings.loanRateFor(months),
      processingFee: fee,
      purpose: purpose,
      disbursedAt: now,
      dueDate: Finance.addMonths(now, months),
    );

    _loans.insert(0, loan);
    await _store.saveLoans(_loans);

    // Booked gross then netted, so the ledger shows both the loan and the
    // fee that came out of it rather than one blended figure.
    await _credit(
      principal,
      TxKind.loanDisbursement,
      'Loan disbursed - $purpose',
      counterparty: 'Kudi9ja Credit',
    );
    await _debit(
      fee,
      TxKind.fee,
      'Processing fee deducted from loan',
      counterparty: 'Kudi9ja Credit',
    );
    await _notify(
      NotifyKind.general,
      'Loan disbursed',
      '${Finance.netDisbursed(principal).toStringAsFixed(0)} reached your wallet after the ${fee.toStringAsFixed(0)} processing fee.',
      amount: Finance.netDisbursed(principal),
    );

    notifyListeners();
    return loan;
  }

  Future<void> repayLoan(String loanId, double amount) async {
    final i = _loans.indexWhere((l) => l.id == loanId);
    if (i < 0) return;
    final l = _loans[i];
    final paid = amount > l.outstanding ? l.outstanding : amount;
    final nextRepaid = l.amountRepaid + paid;
    final settled = nextRepaid >= l.totalRepayable - 0.01;

    _loans[i] = l.copyWith(
      amountRepaid: nextRepaid,
      status: settled ? LoanStatus.repaid : LoanStatus.active,
    );
    await _store.saveLoans(_loans);
    await _debit(paid, TxKind.loanRepayment, 'Loan repayment');
    notifyListeners();
  }

  // ── Notifications ───────────────────────────────────────────────────────
  Future<void> _notify(
    NotifyKind kind,
    String title,
    String body, {
    double? amount,
  }) async {
    _notifications.insert(
      0,
      AppNotification(
        id: _uuid.v4(),
        kind: kind,
        title: title,
        body: body,
        date: DateTime.now(),
        amount: amount,
      ),
    );
    if (_notifications.length > 60) {
      _notifications = _notifications.sublist(0, 60);
    }
    await _store.saveNotifications(_notifications);
  }

  Future<void> markNotificationsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    await _store.saveNotifications(_notifications);
    notifyListeners();
  }

  Future<void> clearNotifications() async {
    _notifications = [];
    await _store.saveNotifications(_notifications);
    notifyListeners();
  }

  // ── Thrift circles (ajo) ────────────────────────────────────────────────
  Future<ThriftCircle> createCircle({
    required String name,
    required String emoji,
    required double contribution,
    required AutoFrequency frequency,
    required List<ThriftMember> members,
  }) async {
    final circle = ThriftCircle(
      id: _uuid.v4(),
      name: name,
      emoji: emoji,
      contribution: contribution,
      frequency: frequency,
      members: members,
      startDate: DateTime.now(),
      createdByMe: true,
      inviteCode: SecurityService.reference('AJO'),
    );
    _circles.insert(0, circle);
    await _store.saveCircles(_circles);
    await _notify(
      NotifyKind.thrift,
      'Circle created',
      '"$name" is live with ${members.length} members. Share your invite code to fill it up.',
    );
    notifyListeners();
    return circle;
  }

  /// Pays this user's contribution into the current round.
  Future<void> contributeToCircle(String circleId) async {
    final i = _circles.indexWhere((c) => c.id == circleId);
    if (i < 0) return;
    final c = _circles[i];
    if (c.hasPaidThisRound) return;

    await _debit(
      c.contribution,
      TxKind.savingsLock,
      'Contribution to "${c.name}" — round ${c.currentRound}',
      counterparty: c.name,
    );

    _circles[i] = c.copyWith(roundsPaid: [...c.roundsPaid, c.currentRound]);
    await _store.saveCircles(_circles);
    await _notify(
      NotifyKind.thrift,
      'Contribution received',
      'Round ${c.currentRound} of "${c.name}" is settled on your side.',
      amount: c.contribution,
    );
    notifyListeners();
  }

  /// Advances the rotation. When it is this user's turn, the pot is paid out.
  Future<double> advanceCircle(String circleId) async {
    final i = _circles.indexWhere((c) => c.id == circleId);
    if (i < 0) return 0;
    final c = _circles[i];
    if (c.isComplete) return 0;

    var payout = 0.0;
    if (c.currentRound == c.myRound) {
      payout = c.potSize;
      await _credit(
        payout,
        TxKind.savingsRelease,
        'Payout from "${c.name}" — your turn',
        counterparty: c.name,
      );
      await _notify(
        NotifyKind.thrift,
        'You collected the pot',
        '${payout.toStringAsFixed(0)} from "${c.name}" is in your wallet.',
        amount: payout,
      );
    }

    _circles[i] = c.copyWith(currentRound: c.currentRound + 1);
    await _store.saveCircles(_circles);
    notifyListeners();
    return payout;
  }

  Future<void> leaveCircle(String circleId) async {
    _circles.removeWhere((c) => c.id == circleId);
    await _store.saveCircles(_circles);
    notifyListeners();
  }

  // ── Loan servicing ──────────────────────────────────────────────────────
  Future<void> setAutoDebit(bool on) async {
    _autoDebit = on;
    await _store.setAutoDebit(on);
    notifyListeners();
  }

  /// Clears a loan ahead of schedule and books the interest rebate.
  Future<({double paid, double rebate})> payOffEarly(String loanId) async {
    final i = _loans.indexWhere((l) => l.id == loanId);
    if (i < 0) return (paid: 0.0, rebate: 0.0);

    final l = _loans[i];
    final rebate = Finance.earlyPayoffRebate(l);
    final due = l.outstanding - rebate;

    _loans[i] = l.copyWith(
      amountRepaid: l.totalRepayable,
      status: LoanStatus.repaid,
    );
    await _store.saveLoans(_loans);
    await _debit(due, TxKind.loanRepayment, 'Early settlement — ${l.purpose} loan');
    await _notify(
      NotifyKind.repaymentPaid,
      'Loan settled early',
      'You cleared your ${l.purpose} loan and saved ${rebate.toStringAsFixed(0)} in interest.',
      amount: rebate,
    );
    notifyListeners();
    return (paid: due, rebate: rebate);
  }

  // ── Admin ───────────────────────────────────────────────────────────────
  List<AdminUser> get admins =>
      List.unmodifiable(_admins..sort((a, b) => a.role.index - b.role.index));

  List<AuditEntry> get auditLog =>
      List.unmodifiable(_audit..sort((a, b) => b.date.compareTo(a.date)));

  PlatformSettings get platformSettings => settings;

  /// The admin record matching the signed-in account, if there is one.
  AdminUser? get currentAdmin {
    final email = _user?.email.toLowerCase();
    if (email == null) return null;
    for (final a in _admins) {
      if (a.email.toLowerCase() == email && a.active) return a;
    }
    return null;
  }

  /// Drives the "Go to admin" entry point on the dashboard.
  bool get isAdmin => currentAdmin != null;

  AdminRole get adminRole => currentAdmin?.role ?? AdminRole.viewer;

  /// The first account opened on a device becomes the owner, so the panel is
  /// reachable at all. Every later admin is added from inside it.
  Future<void> _seedOwnerIfNeeded(AppUser user) async {
    if (_admins.isNotEmpty) return;
    _admins = [
      AdminUser(
        id: _uuid.v4(),
        name: user.fullName,
        email: user.email,
        phone: user.phone,
        role: AdminRole.owner,
        addedAt: DateTime.now(),
        addedBy: 'System (first account on device)',
      ),
    ];
    await _store.saveAdmins(_admins);
    await _log(
      AuditCategory.team,
      'Owner provisioned',
      '${user.fullName} became owner as the first account on this device.',
    );
  }

  Future<void> _log(
    AuditCategory category,
    String action,
    String detail,
  ) async {
    _audit.insert(
      0,
      AuditEntry(
        id: _uuid.v4(),
        actor: _user?.fullName ?? 'System',
        action: action,
        detail: detail,
        date: DateTime.now(),
        category: category,
      ),
    );
    if (_audit.length > 200) _audit = _audit.sublist(0, 200);
    await _store.saveAudit(_audit);
  }

  /// Grants panel access to an email address.
  /// Grants panel access to an account that already exists.
  ///
  /// Membership is keyed on the **email address** and nothing else: access is
  /// matched on it at every sign-in, so it is the only field that decides
  /// anything. The name and phone are copied off the chosen account for the
  /// team list to show — never typed, so an owner cannot grant access to an
  /// address nobody holds by mistyping it.
  Future<({bool ok, String message})> addAdmin({
    required CustomerRecord customer,
    required AdminRole role,
  }) async {
    final clean = customer.email.trim().toLowerCase();
    if (clean.isEmpty) {
      return (ok: false, message: 'That account has no email address.');
    }
    if (_admins.any((a) => a.email.toLowerCase() == clean)) {
      return (ok: false, message: 'That email already has panel access.');
    }
    if (!adminRole.canManageTeam) {
      return (ok: false, message: 'Only an owner can add admins.');
    }

    _admins.add(
      AdminUser(
        id: _uuid.v4(),
        name: customer.fullName.trim().isEmpty
            ? clean
            : customer.fullName.trim(),
        email: clean,
        phone: customer.phone.trim(),
        role: role,
        addedAt: DateTime.now(),
        addedBy: _user?.fullName ?? 'Unknown',
      ),
    );
    await _store.saveAdmins(_admins);
    await _log(
      AuditCategory.team,
      'Admin added',
      '$clean was granted ${role.label} access.',
    );
    notifyListeners();
    return (ok: true, message: '$clean now has ${role.label} access.');
  }

  Future<void> changeAdminRole(String id, AdminRole role) async {
    final i = _admins.indexWhere((a) => a.id == id);
    if (i < 0 || !adminRole.canManageTeam) return;
    // Demoting yourself would drop the permission that allows the change to
    // be reversed, so your own role is only movable by another owner.
    if (_admins[i].id == currentAdmin?.id) return;
    final before = _admins[i];
    _admins[i] = before.copyWith(role: role);
    await _store.saveAdmins(_admins);
    await _log(
      AuditCategory.team,
      'Role changed',
      '${before.name} moved from ${before.role.label} to ${role.label}.',
    );
    notifyListeners();
  }

  Future<void> setAdminActive(String id, bool active) async {
    final i = _admins.indexWhere((a) => a.id == id);
    if (i < 0 || !adminRole.canManageTeam) return;
    // Suspending yourself would revoke the very permission needed to undo it,
    // so self-suspension is refused outright.
    if (_admins[i].id == currentAdmin?.id) return;
    _admins[i] = _admins[i].copyWith(active: active);
    await _store.saveAdmins(_admins);
    await _log(
      AuditCategory.team,
      active ? 'Access restored' : 'Access suspended',
      '${_admins[i].name} was ${active ? 'reinstated' : 'suspended'}.',
    );
    notifyListeners();
  }

  Future<({bool ok, String message})> removeAdmin(String id) async {
    final i = _admins.indexWhere((a) => a.id == id);
    if (i < 0) return (ok: false, message: 'Admin not found.');
    if (!adminRole.canManageTeam) {
      return (ok: false, message: 'Only an owner can remove admins.');
    }
    final target = _admins[i];
    if (target.id == currentAdmin?.id) {
      return (
        ok: false,
        message: 'You cannot remove your own access from inside the panel.',
      );
    }
    if (target.role == AdminRole.owner &&
        _admins.where((a) => a.role == AdminRole.owner).length == 1) {
      return (
        ok: false,
        message: 'You cannot remove the last owner — promote someone first.',
      );
    }

    _admins.removeAt(i);
    await _store.saveAdmins(_admins);
    await _log(
      AuditCategory.team,
      'Admin removed',
      '${target.name} (${target.email}) lost panel access.',
    );
    notifyListeners();
    return (ok: true, message: '${target.name} no longer has access.');
  }

  /// Persists a settings change and records exactly what moved.
  Future<void> updatePlatformSettings(
    PlatformSettings next,
    List<String> changes,
  ) async {
    applySettings(next);
    await _store.savePlatformSettings(next);
    if (changes.isNotEmpty) {
      await _log(
        AuditCategory.settings,
        'Settings updated',
        changes.join(' • '),
      );
    }
    notifyListeners();
  }

  Future<void> logAdminAction(
    AuditCategory category,
    String action,
    String detail,
  ) async {
    await _log(category, action, detail);
    notifyListeners();
  }

  // ── Admin: customer view ────────────────────────────────────────────────
  /// The account on this device, expressed as an admin customer record.
  CustomerRecord? get thisDeviceCustomer {
    final u = _user;
    if (u == null) return null;
    return CustomerRecord(
      id: u.id,
      fullName: u.fullName,
      email: u.email,
      phone: u.phone,
      accountNumber: u.customerRef,
      joinedAt: u.createdAt,
      balance: _balance,
      totalSaved: totalSaved,
      totalOwed: totalOwed,
      interestPaid: totalInterestEarned,
      creditScore: creditScore,
      plansCount: _plans.length,
      loansCount: _loans.length,
      state: u.state,
      bvn: u.bvn,
      nin: u.nin,
      address: u.address,
      gender: u.gender,
      dateOfBirth: u.dateOfBirth,
      verified: u.kycTier == KycTier.tier2,
      isThisDevice: true,
    );
  }

  /// Real account first, then clearly-labelled sample rows standing in for
  /// the wider book a live API would return.
  List<CustomerRecord> get customers => [
    if (thisDeviceCustomer != null) thisDeviceCustomer!,
    ..._sampleCustomers,
  ];

  static final _sampleCustomers = <CustomerRecord>[
    CustomerRecord(
      id: 'sample-1',
      fullName: 'Chioma Adeyemi',
      email: 'chioma.adeyemi@example.com',
      phone: '08031234567',
      accountNumber: '8031234567',
      joinedAt: DateTime(2026, 3, 14),
      balance: 184500,
      totalSaved: 1250000,
      totalOwed: 0,
      interestPaid: 212500,
      creditScore: 782,
      plansCount: 4,
      loansCount: 2,
      state: 'Lagos',
      bvn: 22134567890.toString(),
      nin: 70123456789.toString(),
      address: '14 Adeola Odeku Street, Victoria Island',
      gender: 'Female',
      isSample: true,
    ),
    CustomerRecord(
      id: 'sample-2',
      fullName: 'Ibrahim Musa Bello',
      email: 'ibrahim.bello@example.com',
      phone: '08099887766',
      accountNumber: '8099887766',
      joinedAt: DateTime(2026, 5, 2),
      balance: 42300,
      totalSaved: 300000,
      totalOwed: 168000,
      interestPaid: 51000,
      creditScore: 648,
      plansCount: 2,
      loansCount: 1,
      state: 'Kano',
      bvn: 22198765432.toString(),
      nin: 70198765432.toString(),
      address: '7 Zoo Road, Kano',
      gender: 'Male',
      isSample: true,
    ),
    CustomerRecord(
      id: 'sample-3',
      fullName: 'Ngozi Emeka Okafor',
      email: 'ngozi.okafor@example.com',
      phone: '07044556677',
      accountNumber: '7044556677',
      joinedAt: DateTime(2026, 7, 21),
      balance: 9800,
      totalSaved: 75000,
      totalOwed: 260000,
      interestPaid: 6375,
      creditScore: 521,
      plansCount: 1,
      loansCount: 1,
      state: 'Enugu',
      bvn: 22111222333.toString(),
      nin: 70111222333.toString(),
      address: '22 Ogui Road, Enugu',
      gender: 'Female',
      isSample: true,
    ),
    CustomerRecord(
      id: 'sample-4',
      fullName: 'Tunde Olawale Johnson',
      email: 'tunde.johnson@example.com',
      phone: '08122334455',
      accountNumber: '8122334455',
      joinedAt: DateTime(2026, 8, 9),
      balance: 512000,
      totalSaved: 2400000,
      totalOwed: 480000,
      interestPaid: 408000,
      creditScore: 810,
      plansCount: 6,
      loansCount: 3,
      state: 'Oyo',
      bvn: 22144556677.toString(),
      nin: 70144556677.toString(),
      address: '5 Bodija Estate, Ibadan',
      gender: 'Male',
      isSample: true,
    ),
  ];

  // ── Admin: platform metrics ─────────────────────────────────────────────
  /// Book-wide figures across every customer the panel can see.
  ({
    int customers,
    double deposits,
    double saved,
    double lent,
    double interestPaid,
    int activePlans,
    int activeLoans,
    double overdue,
  })
  get platformMetrics {
    final all = customers;
    return (
      customers: all.length,
      deposits: all.fold(0.0, (s, c) => s + c.balance),
      saved: all.fold(0.0, (s, c) => s + c.totalSaved),
      lent: all.fold(0.0, (s, c) => s + c.totalOwed),
      interestPaid: all.fold(0.0, (s, c) => s + c.interestPaid),
      activePlans: all.fold(0, (s, c) => s + c.plansCount),
      activeLoans: all.fold(0, (s, c) => s + c.loansCount),
      overdue: _loans
          .where((l) => l.status == LoanStatus.overdue)
          .fold(0.0, (s, l) => s + l.outstanding),
    );
  }

  // ── Incoming payments ───────────────────────────────────────────────────
  List<DepositClaim> get deposits => List.unmodifiable(
    _deposits..sort((a, b) => b.claimedAt.compareTo(a.claimedAt)),
  );

  List<DepositClaim> get pendingDeposits =>
      _deposits.where((d) => d.isPending).toList();

  int get pendingDepositCount => pendingDeposits.length;

  double get pendingDepositValue =>
      pendingDeposits.fold(0.0, (s, d) => s + d.amount);

  /// Everything waiting on an admin, in or out.
  int get pendingPaymentCount => pendingDepositCount + pendingWithdrawalCount;

  /// The narration a customer must quote so a transfer can be matched.
  ///
  /// Every pay-in gets its **own** reference, not one shared across all of a
  /// customer's payments: two transfers of the same amount on the same day
  /// are otherwise impossible to tell apart on a bank statement. The
  /// customer's own code is embedded in it, so an admin reading a narration
  /// can find the person without a lookup.
  ///
  ///     K9-A1B2C3-7F4K
  ///     ^^^^^^^^^ the customer   ^^^^ this payment
  String newPaymentReference() {
    final base = _user?.customerRef ?? 'K9-000000';
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final suffix = List.generate(
      4,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    return '$base-$suffix';
  }

  /// A customer says they have paid into the collection account. Nothing
  /// moves until an admin matches the receipt against the bank statement.
  Future<DepositClaim> submitDepositClaim({
    required double amount,
    required DepositPurpose purpose,
    /// The narration the customer was shown and quoted on the transfer.
    /// Generated by [newPaymentReference] when the pay-in screen opened.
    required String reference,
    String receiptPath = '',
    String senderName = '',
    String? loanId,
    String loanPurpose = '',
  }) async {
    final claim = DepositClaim(
      id: _uuid.v4(),
      customerName: _user?.fullName ?? 'Customer',
      customerAccount: _user?.customerRef ?? '',
      amount: amount,
      claimedAt: DateTime.now(),
      reference: reference,
      purpose: purpose,
      loanId: loanId,
      loanPurpose: loanPurpose,
      receiptPath: receiptPath,
      senderName: senderName,
    );

    _deposits.insert(0, claim);
    await _store.saveDeposits(_deposits);
    await _notify(
      NotifyKind.general,
      'Payment submitted',
      'Your ${amount.toStringAsFixed(0)} ${purpose == DepositPurpose.loanRepayment ? 'loan repayment' : 'transfer'} is with our team. We will confirm it against the bank statement shortly.',
      amount: amount,
    );

    notifyListeners();
    return claim;
  }

  /// Admin has matched the receipt to the statement. Credits the wallet, or
  /// reduces the loan, depending on what the customer said it was for.
  Future<void> confirmDeposit(String id) async {
    final i = _deposits.indexWhere((d) => d.id == id);
    if (i < 0 || !_deposits[i].isPending) return;
    if (!adminRole.canActOnLoans) return;

    final d = _deposits[i];
    _deposits[i] = d.copyWith(
      status: DepositStatus.confirmed,
      reviewedAt: DateTime.now(),
      reviewedBy: _user?.fullName ?? 'Admin',
    );
    await _store.saveDeposits(_deposits);

    if (d.isLoanRepayment && d.loanId != null) {
      // The money never entered the wallet, so credit it and immediately
      // apply it to the loan — the ledger shows both legs.
      await _credit(
        d.amount,
        TxKind.deposit,
        'Transfer confirmed for loan repayment',
        counterparty: settings.companyBank,
      );
      await repayLoan(d.loanId!, d.amount);
      await _notify(
        NotifyKind.repaymentPaid,
        'Repayment confirmed',
        'Your ${d.amount.toStringAsFixed(0)} payment has been confirmed and applied to your ${d.loanPurpose} loan.',
        amount: d.amount,
      );
    } else {
      await _credit(
        d.amount,
        TxKind.deposit,
        'Bank transfer confirmed',
        counterparty: settings.companyBank,
      );
      await _notify(
        NotifyKind.general,
        'Payment confirmed',
        '${d.amount.toStringAsFixed(0)} has been added to your wallet.',
        amount: d.amount,
      );
    }

    await _log(
      AuditCategory.customer,
      'Payment confirmed',
      '${d.amount.toStringAsFixed(0)} from ${d.customerName} (${d.reference}) confirmed as ${d.purpose.label.toLowerCase()}.',
    );
    notifyListeners();
  }

  /// Admin could not find the payment, or the receipt does not match.
  Future<void> rejectDeposit(String id, String reason) async {
    final i = _deposits.indexWhere((d) => d.id == id);
    if (i < 0 || !_deposits[i].isPending) return;
    if (!adminRole.canActOnLoans) return;

    final d = _deposits[i];
    _deposits[i] = d.copyWith(
      status: DepositStatus.rejected,
      reviewedAt: DateTime.now(),
      reviewedBy: _user?.fullName ?? 'Admin',
      note: reason,
    );
    await _store.saveDeposits(_deposits);

    // Nothing was ever credited, so there is no money to reverse.
    await _notify(
      NotifyKind.general,
      'Payment not confirmed',
      reason.isEmpty
          ? 'We could not match your ${d.amount.toStringAsFixed(0)} payment. Please contact support.'
          : 'We could not confirm your ${d.amount.toStringAsFixed(0)} payment. Reason: $reason',
      amount: d.amount,
    );
    await _log(
      AuditCategory.customer,
      'Payment rejected',
      '${d.amount.toStringAsFixed(0)} from ${d.customerName} (${d.reference}) rejected. Reason: ${reason.isEmpty ? 'none given' : reason}',
    );
    notifyListeners();
  }

  // ── Withdrawals ─────────────────────────────────────────────────────────
  List<WithdrawalRequest> get withdrawals => List.unmodifiable(
    _withdrawals..sort((a, b) => b.requestedAt.compareTo(a.requestedAt)),
  );

  List<WithdrawalRequest> get pendingWithdrawals =>
      _withdrawals.where((w) => w.isPending).toList();

  int get pendingWithdrawalCount => pendingWithdrawals.length;

  double get pendingWithdrawalValue =>
      pendingWithdrawals.fold(0.0, (s, w) => s + w.amount);

  /// Releases the money to the customer's bank. The wallet was already
  /// debited when they asked, so approval only settles the record.
  Future<void> approveWithdrawal(String id) async {
    final i = _withdrawals.indexWhere((w) => w.id == id);
    if (i < 0 || !_withdrawals[i].isPending) return;
    if (!adminRole.canActOnLoans) return;

    final w = _withdrawals[i];
    _withdrawals[i] = w.copyWith(
      status: WithdrawalStatus.approved,
      reviewedAt: DateTime.now(),
      reviewedBy: _user?.fullName ?? 'Admin',
    );
    await _store.saveWithdrawals(_withdrawals);

    final t = _txns.indexWhere((tx) => tx.id == id);
    if (t >= 0) {
      _txns[t] = _txns[t].copyWith(
        status: TxStatus.successful,
        description: 'Withdrawal to ${w.bank}',
      );
      await _store.saveTransactions(_txns);
    }

    await _notify(
      NotifyKind.general,
      'Withdrawal approved',
      '${w.amount.toStringAsFixed(0)} is on its way to your ${w.bank} account.',
      amount: w.amount,
    );
    await _log(
      AuditCategory.customer,
      'Withdrawal approved',
      '${w.amount.toStringAsFixed(0)} to ${w.bank} for ${w.customerName} (${w.reference}).',
    );
    notifyListeners();
  }

  /// Refuses the request and puts every naira back in the wallet.
  Future<void> declineWithdrawal(String id, String reason) async {
    final i = _withdrawals.indexWhere((w) => w.id == id);
    if (i < 0 || !_withdrawals[i].isPending) return;
    if (!adminRole.canActOnLoans) return;

    final w = _withdrawals[i];
    _withdrawals[i] = w.copyWith(
      status: WithdrawalStatus.declined,
      reviewedAt: DateTime.now(),
      reviewedBy: _user?.fullName ?? 'Admin',
      note: reason,
    );
    await _store.saveWithdrawals(_withdrawals);

    final t = _txns.indexWhere((tx) => tx.id == id);
    if (t >= 0) {
      _txns[t] = _txns[t].copyWith(
        status: TxStatus.reversed,
        description: 'Withdrawal to ${w.bank} - declined',
      );
    }

    await _credit(
      w.amount,
      TxKind.deposit,
      'Refund: withdrawal declined',
      counterparty: 'Kudi9ja',
    );
    await _notify(
      NotifyKind.general,
      'Withdrawal declined',
      reason.isEmpty
          ? '${w.amount.toStringAsFixed(0)} has been returned to your wallet.'
          : '${w.amount.toStringAsFixed(0)} has been returned to your wallet. Reason: $reason',
      amount: w.amount,
    );
    await _log(
      AuditCategory.customer,
      'Withdrawal declined',
      '${w.amount.toStringAsFixed(0)} to ${w.bank} for ${w.customerName} refunded. Reason: ${reason.isEmpty ? 'none given' : reason}',
    );
    notifyListeners();
  }

  /// Every transaction on a customer's record, for the admin panel. The
  /// device account returns its real ledger; sample customers return a
  /// clearly-labelled illustrative history.
  /// Every pay-in this customer has claimed, newest first — pending ones
  /// included, so an admin sees what is waiting on them without leaving the
  /// customer's record.
  List<DepositClaim> depositsFor(CustomerRecord customer) => customer
      .isThisDevice
      ? deposits
      : const <DepositClaim>[];

  /// Every withdrawal this customer has requested, newest first.
  List<WithdrawalRequest> withdrawalsFor(CustomerRecord customer) => customer
      .isThisDevice
      ? withdrawals
      : const <WithdrawalRequest>[];

  List<Transaction> transactionsFor(CustomerRecord customer) =>
      customer.isThisDevice ? transactions : _sampleLedger(customer);

  static final Map<String, List<Transaction>> _sampleLedgers = {};

  List<Transaction> _sampleLedger(CustomerRecord c) =>
      _sampleLedgers.putIfAbsent(c.id, () => _buildSampleLedger(c));

  /// Deterministic illustrative history so the admin filters are usable
  /// against every row, not just the live account.
  List<Transaction> _buildSampleLedger(CustomerRecord c) {
    final now = DateTime.now();
    final seed = c.id.hashCode.abs();
    double balance = c.balance;

    final specs = <({TxKind kind, double amount, String label, int daysAgo})>[
      (
        kind: TxKind.deposit,
        amount: 50000 + (seed % 7) * 10000,
        label: 'Wallet funded via Card',
        daysAgo: 2,
      ),
      (
        kind: TxKind.savingsLock,
        amount: 25000 + (seed % 5) * 5000,
        label: 'Saved into "Target plan"',
        daysAgo: 5,
      ),
      (
        kind: TxKind.interestPayout,
        amount: c.interestPaid / 3,
        label: 'Upfront return on Fixed Savings',
        daysAgo: 9,
      ),
      (
        kind: TxKind.withdrawal,
        amount: 20000 + (seed % 4) * 5000,
        label: 'Withdrawal to bank',
        daysAgo: 14,
      ),
      if (c.loansCount > 0)
        (
          kind: TxKind.loanDisbursement,
          amount: 100000 + (seed % 3) * 50000,
          label: 'Loan disbursed - Business',
          daysAgo: 21,
        ),
      if (c.loansCount > 0)
        (
          kind: TxKind.fee,
          amount: 5000,
          label: 'Processing fee deducted from loan',
          daysAgo: 21,
        ),
      if (c.totalOwed > 0)
        (
          kind: TxKind.loanRepayment,
          amount: c.totalOwed / 3,
          label: 'Loan repayment',
          daysAgo: 26,
        ),
      (
        kind: TxKind.transfer,
        amount: 8000 + (seed % 6) * 1000,
        label: 'Transfer to a friend',
        daysAgo: 33,
      ),
    ];

    return [
      for (final spec in specs)
        Transaction(
          id: '${c.id}-${spec.daysAgo}-${spec.kind.index}',
          kind: spec.kind,
          amount: spec.amount,
          description: spec.label,
          date: now.subtract(Duration(days: spec.daysAgo)),
          balanceAfter: balance = spec.kind.isCredit
              ? balance + spec.amount
              : balance - spec.amount,
          reference: 'K9-SAMPLE-${c.id.toUpperCase()}-${spec.daysAgo}',
          counterparty: 'Sample data',
        ),
    ];
  }

  /// The factors behind the credit score, and what each is worth.
  List<CreditFactor> get creditFactors {
    final repaidLoans =
        _loans.where((l) => l.status == LoanStatus.repaid).length;
    final overdue = _loans.any((l) => l.status == LoanStatus.overdue);

    return [
      CreditFactor(
        label: 'Identity verified',
        detail: user?.kycTier == KycTier.tier2
            ? 'BVN and NIN confirmed'
            : 'Complete your KYC',
        points: user?.kycTier == KycTier.tier2 ? 40 : 0,
        maxPoints: 40,
      ),
      CreditFactor(
        label: 'Savings habit',
        detail: '${_plans.length} ${_plans.length == 1 ? 'plan' : 'plans'} opened',
        points: (_plans.length * 18).clamp(0, 90),
        maxPoints: 90,
      ),
      CreditFactor(
        label: 'Amount saved',
        detail: '${totalSaved.toStringAsFixed(0)} locked away',
        points: (totalSaved / 25000).floor().clamp(0, 100),
        maxPoints: 100,
      ),
      CreditFactor(
        label: 'Repayment history',
        detail: repaidLoans == 0
            ? 'No loans repaid yet'
            : '$repaidLoans ${repaidLoans == 1 ? 'loan' : 'loans'} repaid in full',
        points: (repaidLoans * 30).clamp(0, 120),
        maxPoints: 120,
      ),
      CreditFactor(
        label: 'Nothing overdue',
        detail: overdue ? 'You have an overdue loan' : 'All repayments on time',
        points: overdue ? -90 : 0,
        maxPoints: 0,
        negative: overdue,
      ),
    ];
  }

  /// Eligibility ceiling: headroom, tempered by savings history and score.
  double get eligibleLoanAmount {
    if (loanHeadroom <= 0) return 0;
    var cap = settings.loanBaseCap;
    cap += totalSaved * settings.loanSavingsMultiple;
    cap += (creditScore - settings.loanScoreBaseline) * settings.loanScorePerPoint;
    if (cap > loanHeadroom) cap = loanHeadroom;
    if (cap > settings.maxLoanAmount) cap = settings.maxLoanAmount;
    if (cap < settings.minLoanAmount) return 0;
    return (cap / settings.loanOfferRounding).floor() *
        settings.loanOfferRounding;
  }
}
