import '../../core/utils/formatters.dart';
import 'platform_settings.dart';

// ── User ──────────────────────────────────────────────────────────────────

enum KycTier { tier0, tier1, tier2 }

extension KycTierX on KycTier {
  String get label => switch (this) {
    KycTier.tier0 => 'Unverified',
    KycTier.tier1 => 'Verified',
    KycTier.tier2 => 'Fully Verified',
  };
}

class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.bvn,
    required this.nin,
    required this.address,
    required this.state,
    required this.accountNumber,
    required this.createdAt,
    this.kycTier = KycTier.tier2,
    this.emailVerified = true,
    this.phoneVerified = true,
    this.biometricsEnabled = false,
    this.securityQuestion = '',
    this.securityAnswer = '',
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final DateTime dateOfBirth;
  final String gender;
  final String bvn;
  final String nin;
  final String address;
  final String state;
  final String accountNumber;
  final DateTime createdAt;
  final KycTier kycTier;
  final bool emailVerified;
  final bool phoneVerified;
  final bool biometricsEnabled;
  final String securityQuestion;
  final String securityAnswer;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  AppUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? state,
    bool? biometricsEnabled,
    KycTier? kycTier,
  }) => AppUser(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    dateOfBirth: dateOfBirth,
    gender: gender,
    bvn: bvn,
    nin: nin,
    address: address ?? this.address,
    state: state ?? this.state,
    accountNumber: accountNumber,
    createdAt: createdAt,
    kycTier: kycTier ?? this.kycTier,
    emailVerified: emailVerified,
    phoneVerified: phoneVerified,
    biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'dateOfBirth': dateOfBirth.toIso8601String(),
    'gender': gender,
    'bvn': bvn,
    'nin': nin,
    'address': address,
    'state': state,
    'accountNumber': accountNumber,
    'createdAt': createdAt.toIso8601String(),
    'kycTier': kycTier.index,
    'emailVerified': emailVerified,
    'phoneVerified': phoneVerified,
    'biometricsEnabled': biometricsEnabled,
    'securityQuestion': securityQuestion,
    'securityAnswer': securityAnswer,
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as String,
    fullName: j['fullName'] as String,
    email: j['email'] as String,
    phone: j['phone'] as String,
    dateOfBirth: DateTime.parse(j['dateOfBirth'] as String),
    gender: j['gender'] as String? ?? '',
    bvn: j['bvn'] as String? ?? '',
    nin: j['nin'] as String? ?? '',
    address: j['address'] as String? ?? '',
    state: j['state'] as String? ?? '',
    accountNumber: j['accountNumber'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    kycTier: KycTier.values[j['kycTier'] as int? ?? 2],
    emailVerified: j['emailVerified'] as bool? ?? true,
    phoneVerified: j['phoneVerified'] as bool? ?? true,
    biometricsEnabled: j['biometricsEnabled'] as bool? ?? false,
    securityQuestion: j['securityQuestion'] as String? ?? '',
    securityAnswer: j['securityAnswer'] as String? ?? '',
  );
}

// ── Savings ───────────────────────────────────────────────────────────────

enum SavingsStatus { active, matured, withdrawn, broken }

extension SavingsStatusX on SavingsStatus {
  String get label => switch (this) {
    SavingsStatus.active => 'Locked',
    SavingsStatus.matured => 'Matured',
    SavingsStatus.withdrawn => 'Withdrawn',
    SavingsStatus.broken => 'Broken early',
  };
}

/// The two ways to save on Kudi9ja. They differ in when the return is paid
/// and whether the plan can be broken at all.
enum SavingsType {
  /// One lump sum. Pays 17% into the wallet the instant it starts, and can
  /// never be broken — the principal is untouchable until maturity.
  fixed,

  /// Contributions pulled from the wallet daily or weekly. Pays a 10% bonus
  /// on the final day, and can be broken at any time — but breaking it
  /// forfeits the entire bonus.
  target,
}

extension SavingsTypeX on SavingsType {
  String get label => switch (this) {
    SavingsType.fixed => 'Fixed Savings',
    SavingsType.target => 'Target Savings',
  };

  String get blurb => switch (this) {
    SavingsType.fixed => 'One amount locked away. 17% paid to you today.',
    SavingsType.target =>
      'Save a set amount daily or weekly. 10% bonus on the last day.',
  };

  /// Fixed plans cannot be broken under any circumstance.
  bool get canBreak => this == SavingsType.target;
}

enum AutoFrequency { daily, weekly, monthly }

extension AutoFrequencyX on AutoFrequency {
  String get label => switch (this) {
    AutoFrequency.daily => 'Daily',
    AutoFrequency.weekly => 'Weekly',
    AutoFrequency.monthly => 'Monthly',
  };

  String get adverb => switch (this) {
    AutoFrequency.daily => 'every day',
    AutoFrequency.weekly => 'every week',
    AutoFrequency.monthly => 'every month',
  };

  Duration get interval => switch (this) {
    AutoFrequency.daily => const Duration(days: 1),
    AutoFrequency.weekly => const Duration(days: 7),
    AutoFrequency.monthly => const Duration(days: 30),
  };

  /// Contributions per year — used to project a goal's finish date.
  int get perYear => switch (this) {
    AutoFrequency.daily => 365,
    AutoFrequency.weekly => 52,
    AutoFrequency.monthly => 12,
  };
}

class SavingsPlan {
  SavingsPlan({
    required this.id,
    required this.title,
    required this.principal,
    required this.lockMonths,
    required this.interestPaid,
    required this.startDate,
    required this.maturityDate,
    this.status = SavingsStatus.active,
    this.type = SavingsType.fixed,
    this.targetAmount,
    this.emoji = '🎯',
    this.autoFrequency,
    this.autoAmount,
    this.nextAutoRun,
    this.autoEnabled = false,
    this.contributions = 1,
    this.bonusRate = 0,
    this.bonusPaid = false,
  });

  final String id;
  final String title;
  final double principal;
  final int lockMonths;

  /// The 17% return, credited to the wallet the instant the plan was created.
  final double interestPaid;
  final DateTime startDate;
  final DateTime maturityDate;
  final SavingsStatus status;

  final SavingsType type;

  /// Only set on goal plans — the amount the user is working towards.
  final double? targetAmount;
  final String emoji;

  // Auto-save configuration, only set on [SavingsType.auto] plans.
  final AutoFrequency? autoFrequency;
  final double? autoAmount;
  final DateTime? nextAutoRun;
  final bool autoEnabled;

  /// How many separate deposits have gone into this plan.
  final int contributions;

  /// Target Savings only: the share of the amount saved paid as a lump sum
  /// on the final day. Zero on Fixed Savings, which pays upfront instead.
  final double bonusRate;

  /// Whether that lump sum has already been credited.
  final bool bonusPaid;

  bool get isFixed => type == SavingsType.fixed;
  bool get isTarget => type == SavingsType.target;

  /// Fixed plans are untouchable; target plans can be broken any time while
  /// they are still running.
  bool get canBreak => isTarget && status == SavingsStatus.active;

  /// What the bonus is worth right now, on the money actually saved. A plan
  /// run to term earns 10% of everything that went in.
  double get bonusEarned => principal * bonusRate;

  /// The bonus a completed plan would pay, based on the full schedule.
  double get projectedBonus => (targetAmount ?? principal) * bonusRate;

  /// Principal plus every naira of return already credited.
  double get totalValue => principal + interestPaid;

  /// What lands in the wallet if the plan runs to maturity.
  double get valueAtMaturity => isFixed
      ? principal
      : (targetAmount ?? principal) + projectedBonus;

  bool get isMature => DateTime.now().isAfter(maturityDate);

  bool get isOpen =>
      status == SavingsStatus.active || status == SavingsStatus.matured;

  /// 0.0 to 1.0 progress through the lock period.
  double get progress {
    final total = maturityDate.difference(startDate).inSeconds;
    if (total <= 0) return 1;
    final done = DateTime.now().difference(startDate).inSeconds;
    return (done / total).clamp(0.0, 1.0);
  }

  /// 0.0 to 1.0 progress towards [targetAmount]. Falls back to time
  /// progress for plans that have no target.
  double get goalProgress {
    final target = targetAmount;
    if (target == null || target <= 0) return progress;
    return (principal / target).clamp(0.0, 1.0);
  }

  bool get goalReached =>
      targetAmount != null && principal >= targetAmount! - 0.01;

  double get amountLeftToTarget {
    final target = targetAmount;
    if (target == null) return 0;
    final left = target - principal;
    return left < 0 ? 0 : left;
  }

  int get daysRemaining {
    final d = maturityDate.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  /// True when an auto-save contribution is due to run.
  bool get autoIsDue =>
      autoEnabled &&
      nextAutoRun != null &&
      DateTime.now().isAfter(nextAutoRun!) &&
      status == SavingsStatus.active;

  SavingsPlan copyWith({
    String? title,
    double? principal,
    double? interestPaid,
    SavingsStatus? status,
    double? targetAmount,
    AutoFrequency? autoFrequency,
    double? autoAmount,
    DateTime? nextAutoRun,
    bool? autoEnabled,
    int? contributions,
    DateTime? maturityDate,
    bool? bonusPaid,
  }) => SavingsPlan(
    id: id,
    title: title ?? this.title,
    principal: principal ?? this.principal,
    lockMonths: lockMonths,
    interestPaid: interestPaid ?? this.interestPaid,
    startDate: startDate,
    maturityDate: maturityDate ?? this.maturityDate,
    status: status ?? this.status,
    type: type,
    targetAmount: targetAmount ?? this.targetAmount,
    emoji: emoji,
    autoFrequency: autoFrequency ?? this.autoFrequency,
    autoAmount: autoAmount ?? this.autoAmount,
    nextAutoRun: nextAutoRun ?? this.nextAutoRun,
    autoEnabled: autoEnabled ?? this.autoEnabled,
    contributions: contributions ?? this.contributions,
    bonusRate: bonusRate,
    bonusPaid: bonusPaid ?? this.bonusPaid,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'principal': principal,
    'lockMonths': lockMonths,
    'interestPaid': interestPaid,
    'startDate': startDate.toIso8601String(),
    'maturityDate': maturityDate.toIso8601String(),
    'status': status.index,
    'type': type.index,
    'targetAmount': targetAmount,
    'emoji': emoji,
    'autoFrequency': autoFrequency?.index,
    'autoAmount': autoAmount,
    'nextAutoRun': nextAutoRun?.toIso8601String(),
    'autoEnabled': autoEnabled,
    'contributions': contributions,
    'bonusRate': bonusRate,
    'bonusPaid': bonusPaid,
  };

  factory SavingsPlan.fromJson(Map<String, dynamic> j) => SavingsPlan(
    id: j['id'] as String,
    title: j['title'] as String,
    principal: (j['principal'] as num).toDouble(),
    lockMonths: j['lockMonths'] as int,
    interestPaid: (j['interestPaid'] as num).toDouble(),
    startDate: DateTime.parse(j['startDate'] as String),
    maturityDate: DateTime.parse(j['maturityDate'] as String),
    status: SavingsStatus.values[j['status'] as int],
    type: SavingsType.values[j['type'] as int? ?? 0],
    targetAmount: (j['targetAmount'] as num?)?.toDouble(),
    emoji: j['emoji'] as String? ?? '🎯',
    autoFrequency: j['autoFrequency'] == null
        ? null
        : AutoFrequency.values[j['autoFrequency'] as int],
    autoAmount: (j['autoAmount'] as num?)?.toDouble(),
    nextAutoRun: j['nextAutoRun'] == null
        ? null
        : DateTime.parse(j['nextAutoRun'] as String),
    autoEnabled: j['autoEnabled'] as bool? ?? false,
    contributions: j['contributions'] as int? ?? 1,
    bonusRate: (j['bonusRate'] as num?)?.toDouble() ?? 0,
    bonusPaid: j['bonusPaid'] as bool? ?? false,
  );
}

// ── Loans ─────────────────────────────────────────────────────────────────

enum LoanStatus { pending, active, repaid, overdue, rejected }

extension LoanStatusX on LoanStatus {
  String get label => switch (this) {
    LoanStatus.pending => 'Under review',
    LoanStatus.active => 'Active',
    LoanStatus.repaid => 'Fully repaid',
    LoanStatus.overdue => 'Overdue',
    LoanStatus.rejected => 'Declined',
  };
}

class Loan {
  Loan({
    required this.id,
    required this.principal,
    required this.tenureMonths,
    required this.flatRate,
    required this.processingFee,
    required this.purpose,
    required this.disbursedAt,
    required this.dueDate,
    this.amountRepaid = 0,
    this.status = LoanStatus.active,
  });

  final String id;
  final double principal;
  final int tenureMonths;

  /// The flat rate charged on [principal], fixed at the rate published for
  /// this loan's tenure on the day it was disbursed. Later rate changes never
  /// touch a running loan.
  final double flatRate;
  final double processingFee;
  final String purpose;
  final DateTime disbursedAt;
  final DateTime dueDate;
  final double amountRepaid;
  final LoanStatus status;

  double get totalInterest => principal * flatRate;
  double get totalRepayable => principal + totalInterest;
  double get monthlyRepayment => totalRepayable / tenureMonths;
  double get outstanding {
    final left = totalRepayable - amountRepaid;
    return left < 0.01 ? 0 : left;
  }

  double get repaymentProgress =>
      totalRepayable <= 0 ? 0 : (amountRepaid / totalRepayable).clamp(0.0, 1.0);

  bool get isOpen => status == LoanStatus.active || status == LoanStatus.overdue;

  /// The full amortisation schedule, derived from what has actually been
  /// repaid so far. Equal instalments, one per month of the tenure.
  List<Installment> get schedule {
    final each = monthlyRepayment;
    var covered = amountRepaid;
    final now = DateTime.now();

    return List.generate(tenureMonths, (i) {
      final due = Finance.addMonths(disbursedAt, i + 1);
      final paidHere = covered >= each ? each : (covered > 0 ? covered : 0.0);
      covered -= paidHere;

      final settled = paidHere >= each - 0.01;
      return Installment(
        number: i + 1,
        dueDate: due,
        amount: each,
        amountPaid: paidHere,
        status: settled
            ? InstallmentStatus.paid
            : (now.isAfter(due)
                  ? InstallmentStatus.overdue
                  : (paidHere > 0
                        ? InstallmentStatus.partial
                        : InstallmentStatus.upcoming)),
      );
    });
  }

  /// The next instalment the user owes, or null once the loan is settled.
  Installment? get nextInstallment {
    for (final i in schedule) {
      if (i.status != InstallmentStatus.paid) return i;
    }
    return null;
  }

  int get installmentsPaid =>
      schedule.where((i) => i.status == InstallmentStatus.paid).length;

  Loan copyWith({double? amountRepaid, LoanStatus? status}) => Loan(
    id: id,
    principal: principal,
    tenureMonths: tenureMonths,
    flatRate: flatRate,
    processingFee: processingFee,
    purpose: purpose,
    disbursedAt: disbursedAt,
    dueDate: dueDate,
    amountRepaid: amountRepaid ?? this.amountRepaid,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'principal': principal,
    'tenureMonths': tenureMonths,
    'flatRate': flatRate,
    'processingFee': processingFee,
    'purpose': purpose,
    'disbursedAt': disbursedAt.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
    'amountRepaid': amountRepaid,
    'status': status.index,
  };

  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
    id: j['id'] as String,
    principal: (j['principal'] as num).toDouble(),
    tenureMonths: j['tenureMonths'] as int,
    flatRate: (j['flatRate'] ?? j['monthlyRate'] as num).toDouble(),
    processingFee: (j['processingFee'] as num).toDouble(),
    purpose: j['purpose'] as String,
    disbursedAt: DateTime.parse(j['disbursedAt'] as String),
    dueDate: DateTime.parse(j['dueDate'] as String),
    amountRepaid: (j['amountRepaid'] as num).toDouble(),
    status: LoanStatus.values[j['status'] as int],
  );
}

enum InstallmentStatus { paid, partial, upcoming, overdue }

extension InstallmentStatusX on InstallmentStatus {
  String get label => switch (this) {
    InstallmentStatus.paid => 'Paid',
    InstallmentStatus.partial => 'Part paid',
    InstallmentStatus.upcoming => 'Upcoming',
    InstallmentStatus.overdue => 'Overdue',
  };
}

/// One row of a loan's repayment schedule.
class Installment {
  const Installment({
    required this.number,
    required this.dueDate,
    required this.amount,
    required this.amountPaid,
    required this.status,
  });

  final int number;
  final DateTime dueDate;
  final double amount;
  final double amountPaid;
  final InstallmentStatus status;

  double get outstanding {
    final left = amount - amountPaid;
    return left < 0.01 ? 0 : left;
  }

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
}

// ── Transactions ──────────────────────────────────────────────────────────

enum TxKind {
  deposit,
  withdrawal,
  transfer,
  savingsLock,
  interestPayout,
  savingsRelease,
  loanDisbursement,
  loanRepayment,
  fee,
}

extension TxKindX on TxKind {
  String get label => switch (this) {
    TxKind.deposit => 'Wallet funding',
    TxKind.withdrawal => 'Withdrawal',
    TxKind.transfer => 'Transfer',
    TxKind.savingsLock => 'Savings lock',
    TxKind.interestPayout => 'Interest payout',
    TxKind.savingsRelease => 'Savings release',
    TxKind.loanDisbursement => 'Loan disbursed',
    TxKind.loanRepayment => 'Loan repayment',
    TxKind.fee => 'Service fee',
  };

  bool get isCredit => switch (this) {
    TxKind.deposit ||
    TxKind.interestPayout ||
    TxKind.savingsRelease ||
    TxKind.loanDisbursement => true,
    _ => false,
  };
}

/// Where a transaction stands. Most settle instantly; withdrawals wait for
/// an admin, and a declined one is reversed.
enum TxStatus { pending, successful, reversed }

extension TxStatusX on TxStatus {
  String get label => switch (this) {
    TxStatus.pending => 'Awaiting approval',
    TxStatus.successful => 'Successful',
    TxStatus.reversed => 'Reversed',
  };
}

class Transaction {
  Transaction({
    required this.id,
    required this.kind,
    required this.amount,
    required this.description,
    required this.date,
    required this.balanceAfter,
    this.reference = '',
    this.counterparty = '',
    this.status = TxStatus.successful,
  });

  final String id;
  final TxKind kind;
  final double amount;
  final String description;
  final DateTime date;
  final double balanceAfter;
  final String reference;
  final String counterparty;
  final TxStatus status;

  bool get isCredit => kind.isCredit;
  bool get isPending => status == TxStatus.pending;

  Transaction copyWith({TxStatus? status, String? description}) => Transaction(
    id: id,
    kind: kind,
    amount: amount,
    description: description ?? this.description,
    date: date,
    balanceAfter: balanceAfter,
    reference: reference,
    counterparty: counterparty,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.index,
    'amount': amount,
    'description': description,
    'date': date.toIso8601String(),
    'balanceAfter': balanceAfter,
    'reference': reference,
    'counterparty': counterparty,
    'status': status.index,
  };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
    id: j['id'] as String,
    kind: TxKind.values[j['kind'] as int],
    amount: (j['amount'] as num).toDouble(),
    description: j['description'] as String,
    date: DateTime.parse(j['date'] as String),
    balanceAfter: (j['balanceAfter'] as num).toDouble(),
    reference: j['reference'] as String? ?? '',
    counterparty: j['counterparty'] as String? ?? '',
    status: TxStatus.values[j['status'] as int? ?? 1],
  );
}

/// The filter set shared by the customer wallet and the admin customer
/// record, so both screens slice history the same way.
enum TxFilter { all, deposits, withdrawals, transfers, savings, loans, fees }

extension TxFilterX on TxFilter {
  String get label => switch (this) {
    TxFilter.all => 'All',
    TxFilter.deposits => 'Deposits',
    TxFilter.withdrawals => 'Withdrawals',
    TxFilter.transfers => 'Transfers',
    TxFilter.savings => 'Savings',
    TxFilter.loans => 'Loans',
    TxFilter.fees => 'Fees',
  };

  bool matches(Transaction tx) => switch (this) {
    TxFilter.all => true,
    TxFilter.deposits => tx.kind == TxKind.deposit,
    TxFilter.withdrawals => tx.kind == TxKind.withdrawal,
    TxFilter.transfers => tx.kind == TxKind.transfer,
    TxFilter.savings =>
      tx.kind == TxKind.savingsLock ||
          tx.kind == TxKind.interestPayout ||
          tx.kind == TxKind.savingsRelease,
    TxFilter.loans =>
      tx.kind == TxKind.loanDisbursement || tx.kind == TxKind.loanRepayment,
    TxFilter.fees => tx.kind == TxKind.fee,
  };
}

// ── Finance engine ────────────────────────────────────────────────────────

/// Every money rule in one place, so the UI never invents its own maths.
abstract final class Finance {
  /// The 17% p.a. return on a Fixed Savings principal locked over [months],
  /// paid into the wallet upfront.
  static double savingsInterest(double principal, int months) =>
      principal * settings.savingsAnnualRate * (months / 12);

  /// Days in a Target Savings term. A month counts as
  /// [PlatformSettings.daysPerSavingsMonth] days, so six months is 180 days
  /// at the shipped setting.
  static int targetDays(int months) => months * settings.daysPerSavingsMonth;

  /// How many deposits a schedule makes over [months].
  static int targetRuns(AutoFrequency freq, int months) {
    final days = targetDays(months);
    return switch (freq) {
      AutoFrequency.daily => days,
      AutoFrequency.weekly => (days / 7).floor(),
      AutoFrequency.monthly => months,
    };
  }

  /// The amount that must go in each time to reach [goal] over the term.
  /// Saving 100,000 over 6 months daily works out at 555.56 a day.
  static double targetPerDeposit(
    double goal,
    AutoFrequency freq,
    int months,
  ) {
    final runs = targetRuns(freq, months);
    return runs <= 0 ? goal : goal / runs;
  }

  /// The bonus rate a term of [months] earns — 2.5%, 5% or 10%.
  static double targetRateFor(int months) => settings.targetRateFor(months);

  /// The lump sum a Target Savings plan pays on its final day.
  static double targetBonus(double totalSaved, int months) =>
      totalSaved * targetRateFor(months);

  static double savingsTotal(double principal, int months) =>
      principal + savingsInterest(principal, months);

  /// Effective yield over the whole lock period, as a percentage.
  static double effectiveYieldPct(int months) =>
      settings.savingsAnnualRate * (months / 12) * 100;

  /// Flat interest on the amount borrowed, at the rate published for a
  /// tenure of [months] — 10% over one month, 15% over two, 25% over three.
  static double loanInterest(double principal, int months) =>
      principal * settings.loanRateFor(months);

  static double loanTotal(double principal, int months) =>
      principal + loanInterest(principal, months);

  static double loanMonthly(double principal, int months) =>
      months <= 0 ? 0 : loanTotal(principal, months) / months;

  /// A flat ₦5,000 on any loan up to and including ₦500,000; 1% of the whole
  /// principal — not of the excess — once the amount goes above that, so
  /// ₦500,001 is charged 1%. The rules meet exactly at the threshold, so the
  /// fee curve is continuous. Always taken out of the disbursement.
  static double processingFee(double principal) =>
      settings.processingFeeFor(principal);

  /// What actually reaches the wallet once the fee is taken off.
  static double netDisbursed(double principal) =>
      settings.netDisbursedFor(principal);

  /// Human-readable description of how this loan's fee was worked out.
  static String processingFeeBasis(double principal) =>
      principal <= settings.processingFeeThreshold
      ? 'Flat fee up to ${settings.processingFeeThreshold.asNairaFlat}'
      : '${settings.feeRatePct.toStringAsFixed(0)}% of the whole amount';

  /// Settling a loan early earns back half the interest on the months that
  /// have not yet started — the reward for clearing a debt ahead of time.
  static double earlyPayoffRebate(Loan loan) {
    if (!loan.isOpen) return 0;
    final elapsed = monthsBetween(loan.disbursedAt, DateTime.now());
    final remaining = loan.tenureMonths - elapsed - 1;
    if (remaining <= 0) return 0;
    // A share of the flat interest attributable to the months that never
    // started — half of it at the shipped setting.
    final rebate =
        loan.totalInterest *
        (remaining / loan.tenureMonths) *
        settings.earlyPayoffRebateShare;
    return rebate > loan.outstanding ? loan.outstanding : rebate;
  }

  static double earlyPayoffAmount(Loan loan) =>
      loan.outstanding - earlyPayoffRebate(loan);

  /// Whole months elapsed between two dates.
  static int monthsBetween(DateTime from, DateTime to) {
    final months = (to.year - from.year) * 12 + (to.month - from.month);
    return to.day < from.day ? months - 1 : months;
  }

  /// The per-contribution amount needed to reach [target] by [deadline].
  static double contributionFor(
    double target,
    double alreadySaved,
    DateTime deadline,
    AutoFrequency frequency,
  ) {
    final left = target - alreadySaved;
    if (left <= 0) return 0;
    final days = deadline.difference(DateTime.now()).inDays;
    if (days <= 0) return left;
    final periods = switch (frequency) {
      AutoFrequency.daily => days,
      AutoFrequency.weekly => (days / 7).ceil(),
      AutoFrequency.monthly => (days / 30).ceil(),
    };
    return periods <= 0 ? left : left / periods;
  }

  /// When a goal will be reached at the current contribution rate.
  static DateTime? projectedGoalDate(SavingsPlan plan) {
    final target = plan.targetAmount;
    final amount = plan.autoAmount;
    final freq = plan.autoFrequency;
    if (target == null || amount == null || freq == null || amount <= 0) {
      return null;
    }
    final left = target - plan.principal;
    if (left <= 0) return DateTime.now();
    final periods = (left / amount).ceil();
    return DateTime.now().add(freq.interval * periods);
  }

  /// Adds [months] calendar months, clamping the day to the target month's end.
  static DateTime addMonths(DateTime from, int months) {
    final totalMonths = from.month - 1 + months;
    final year = from.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      from.day > lastDay ? lastDay : from.day,
      from.hour,
      from.minute,
    );
  }
}
