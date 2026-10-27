import '../../core/constants/app_config.dart';
import 'platform_settings.dart';

export 'platform_settings.dart' show RepaymentFrequency, LendingTerms;

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
    required this.payoutBank,
    required this.payoutAccountNumber,
    required this.createdAt,
    this.kycTier = KycTier.tier2,
    this.emailVerified = true,
    this.phoneVerified = true,
    this.biometricsEnabled = false,
    this.securityQuestion = '',
    this.securityAnswer = '',
    String? customerRef,
  }) : _customerRef = customerRef;

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
  /// Kudi9ja does not issue account numbers. Money leaves the wallet to the
  /// customer's own bank account, which is what these two hold. The name on
  /// it must match [fullName] — we only pay out to the customer.
  final String payoutBank;
  final String payoutAccountNumber;

  /// Whether a payout destination has been set at all.
  bool get hasPayoutAccount =>
      payoutBank.isNotEmpty && payoutAccountNumber.isNotEmpty;
  final DateTime createdAt;
  final KycTier kycTier;
  final bool emailVerified;
  final bool phoneVerified;
  final bool biometricsEnabled;
  final String securityQuestion;
  final String securityAnswer;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  final String? _customerRef;

  /// A short, stable code identifying this customer on a bank transfer and
  /// in the admin queues. It replaces the account number Kudi9ja used to
  /// issue — it is a reference, not an account anyone can pay into directly.
  ///
  /// **The server issues this.** It is what an admin matches a bank statement
  /// against, so a locally invented one would not be found: the derivation
  /// below is a fallback for accounts that predate the app talking to a
  /// server, and for tests, never a second source of truth.
  String get customerRef =>
      _customerRef ??
      'K9-${id.replaceAll('-', '').substring(0, 6).toUpperCase()}';

  AppUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? state,
    String? payoutBank,
    String? payoutAccountNumber,
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
    payoutBank: payoutBank ?? this.payoutBank,
    payoutAccountNumber: payoutAccountNumber ?? this.payoutAccountNumber,
    createdAt: createdAt,
    kycTier: kycTier ?? this.kycTier,
    emailVerified: emailVerified,
    phoneVerified: phoneVerified,
    biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
    customerRef: _customerRef,
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
    'payoutBank': payoutBank,
    'payoutAccountNumber': payoutAccountNumber,
    'createdAt': createdAt.toIso8601String(),
    'kycTier': kycTier.index,
    'emailVerified': emailVerified,
    'phoneVerified': phoneVerified,
    'biometricsEnabled': biometricsEnabled,
    'securityQuestion': securityQuestion,
    'securityAnswer': securityAnswer,
    'customerRef': _customerRef,
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
    payoutBank: j['payoutBank'] as String? ?? '',
    // Accounts opened before Kudi9ja stopped issuing its own numbers carry
    // 'accountNumber'. It was never a real bank account, so it is dropped
    // rather than migrated — the customer sets a payout account instead.
    payoutAccountNumber: j['payoutAccountNumber'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    kycTier: KycTier.values[j['kycTier'] as int? ?? 2],
    emailVerified: j['emailVerified'] as bool? ?? true,
    phoneVerified: j['phoneVerified'] as bool? ?? true,
    biometricsEnabled: j['biometricsEnabled'] as bool? ?? false,
    securityQuestion: j['securityQuestion'] as String? ?? '',
    securityAnswer: j['securityAnswer'] as String? ?? '',
    customerRef: j['customerRef'] as String?,
  );
}

// ── Savings ───────────────────────────────────────────────────────────────

enum SavingsStatus {
  active,
  matured,
  withdrawn,
  broken,

  /// Released before maturity by an administrator, on grounds the customer
  /// asked for and a person agreed to — bereavement, a medical emergency.
  ///
  /// Distinct from [broken] because breaking a plan forfeits the bonus and is
  /// the customer's own doing, while this is a decision made for them and
  /// carries no penalty. Showing one as the other would tell a grieving
  /// customer they had been charged for something they did not do.
  releasedOnCompassionateGrounds,
}

extension SavingsStatusX on SavingsStatus {
  String get label => switch (this) {
    SavingsStatus.active => 'Locked',
    SavingsStatus.matured => 'Matured',
    SavingsStatus.withdrawn => 'Withdrawn',
    SavingsStatus.broken => 'Broken early',
    SavingsStatus.releasedOnCompassionateGrounds => 'Released early',
  };

  /// Whether the plan is finished, whatever finished it.
  bool get isClosed => this != SavingsStatus.active;
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
    required this.lockDays,
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

  /// How long the principal is locked for, in days.
  final int lockDays;

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
    lockDays: lockDays,
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
    'lockDays': lockDays,
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
    // Plans written before locks were counted in days carry 'lockMonths'.
    lockDays:
        j['lockDays'] as int? ??
        ((j['lockMonths'] as num) * AppConfig.daysPerYear / 12).round(),
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

enum LoanStatus {
  pending,
  active,
  repaid,
  overdue,
  rejected,

  /// Cancelled inside the change-of-mind window loans once had. No new loan
  /// reaches this state — a loan in the wallet is repaid in full, with
  /// interest — but the ones already cancelled keep their row.
  cancelled,

  /// Given up on by Kudi9ja after it went bad. The debt is not forgiven — it
  /// stays on the customer's record and can still be pursued — but it stops
  /// accruing and stops appearing as money the business expects to collect.
  writtenOff,
}

extension LoanStatusX on LoanStatus {
  String get label => switch (this) {
    LoanStatus.pending => 'Under review',
    LoanStatus.active => 'Active',
    LoanStatus.repaid => 'Fully repaid',
    LoanStatus.overdue => 'Overdue',
    LoanStatus.rejected => 'Declined',
    LoanStatus.cancelled => 'Cancelled',
    LoanStatus.writtenOff => 'Written off',
  };

  /// Whether the customer still owes anything on this loan.
  ///
  /// A written-off loan is deliberately **not** open: it must not sit in the
  /// customer's list of things to repay or be added into what they owe, even
  /// though the debt itself has not been forgiven.
  bool get isOpen => this == LoanStatus.active || this == LoanStatus.overdue;
}

/// What the server worked out about a loan, as it sends it.
///
/// Held beside the loan rather than recomputed, because the server is the one
/// that charges: a schedule rounded on the phone a naira differently from the
/// one on the server is a customer told they owe a naira they do not.
class LoanFigures {
  const LoanFigures({
    required this.totalInterest,
    required this.totalRepayable,
    required this.outstanding,
    required this.installmentAmount,
    required this.installmentBase,
    required this.installmentFee,
    required this.totalRepaymentFees,
    required this.loanAndInterest,
    required this.netDisbursed,
    required this.settlementAmount,
    required this.repaymentProgress,
    required this.schedule,
    this.rebateGranted = 0,
    this.decisionReasons = '',
  });

  final double totalInterest;
  final double totalRepayable;
  final double outstanding;

  /// One instalment, transaction fee included, and its two parts.
  final double installmentAmount;
  final double installmentBase;
  final double installmentFee;

  /// What the transaction fees on every instalment add up to.
  final double totalRepaymentFees;

  /// The loan and its interest, before the transaction fees.
  final double loanAndInterest;
  final double netDisbursed;

  /// What clears the loan today: everything still owed, interest included.
  final double settlementAmount;
  final double repaymentProgress;
  final List<Installment> schedule;

  /// Interest handed back on an early settlement, on the loans that were
  /// written while that was offered.
  final double rebateGranted;
  final String decisionReasons;

  Map<String, dynamic> toJson() => {
    'totalInterest': totalInterest,
    'totalRepayable': totalRepayable,
    'outstanding': outstanding,
    'installmentAmount': installmentAmount,
    'installmentBase': installmentBase,
    'installmentFee': installmentFee,
    'totalRepaymentFees': totalRepaymentFees,
    'loanAndInterest': loanAndInterest,
    'netDisbursed': netDisbursed,
    'settlementAmount': settlementAmount,
    'repaymentProgress': repaymentProgress,
    'rebateGranted': rebateGranted,
    'decisionReasons': decisionReasons,
    'schedule': schedule.map((i) => i.toJson()).toList(),
  };

  static LoanFigures? fromJson(Object? value) {
    if (value is! Map) return null;
    final j = value.cast<String, dynamic>();
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return LoanFigures(
      totalInterest: n('totalInterest'),
      totalRepayable: n('totalRepayable'),
      outstanding: n('outstanding'),
      installmentAmount: n('installmentAmount'),
      installmentBase: n('installmentBase'),
      installmentFee: n('installmentFee'),
      totalRepaymentFees: n('totalRepaymentFees'),
      loanAndInterest: n('loanAndInterest'),
      netDisbursed: n('netDisbursed'),
      settlementAmount: n('settlementAmount'),
      repaymentProgress: n('repaymentProgress'),
      rebateGranted: n('rebateGranted'),
      decisionReasons: j['decisionReasons'] as String? ?? '',
      schedule: (j['schedule'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Installment.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
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
    this.frequency = RepaymentFrequency.monthly,
    int? installmentCount,
    this.repaymentFeeRate = 0,
    this.transactionFee = 0,
    this.wholeNaira = false,
    this.figures,
  }) : installmentCount =
           installmentCount ?? frequency.installments(tenureMonths, disbursedAt);

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

  /// Weekly or monthly. The tenure is still counted in months.
  final RepaymentFrequency frequency;

  /// How many instalments, fixed on the day the loan was paid out.
  final int installmentCount;

  /// The transaction fee on every repayment, as a fraction: 0.02 for 2%.
  /// Zero on loans priced before it existed.
  final double repaymentFeeRate;

  /// A flat fee taken off the payout — older loans only.
  final double transactionFee;

  /// Instalments in whole naira, rounded up — every loan since the repayment
  /// fee. Older loans were split to the kobo.
  final bool wholeNaira;

  /// The server's own figures, when the loan came from it.
  final LoanFigures? figures;

  /// The loan and its interest, before the transaction fees.
  double get loanAndInterest {
    final f = figures;
    if (f != null) return f.loanAndInterest;
    final total = principal * (1 + flatRate);
    return wholeNaira ? Finance.ceilNaira(total) : total;
  }

  List<InstalmentPart> get _plan => Finance.instalmentPlan(
    loanAndInterest,
    installmentCount,
    repaymentFeeRate,
    wholeNaira: wholeNaira,
  );

  double get totalInterest => figures?.totalInterest ?? loanAndInterest - principal;

  /// What the transaction fees on all the instalments add up to.
  double get totalRepaymentFees =>
      figures?.totalRepaymentFees ?? _plan.fold(0.0, (sum, p) => sum + p.fee);

  /// Everything repaid: the loan, the interest and every transaction fee.
  double get totalRepayable =>
      figures?.totalRepayable ?? loanAndInterest + totalRepaymentFees;

  /// One instalment, fee included. The last can be a little smaller.
  double get installmentAmount {
    final f = figures;
    if (f != null) return f.installmentAmount;
    final plan = _plan;
    return plan.isEmpty ? 0 : plan.first.total;
  }

  /// The share of the loan and interest in one instalment, and the fee on it.
  double get installmentBase {
    final f = figures;
    if (f != null) return f.installmentBase;
    final plan = _plan;
    return plan.isEmpty ? 0 : plan.first.base;
  }

  double get installmentFee {
    final f = figures;
    if (f != null) return f.installmentFee;
    final plan = _plan;
    return plan.isEmpty ? 0 : plan.first.fee;
  }

  /// What reached the wallet: the loan less the management fee (and, on an
  /// older loan, the flat transaction fee).
  double get netDisbursed =>
      figures?.netDisbursed ?? principal - processingFee - transactionFee;

  double get outstanding {
    final f = figures;
    if (f != null) return f.outstanding;
    final left = totalRepayable - amountRepaid;
    return left < 0.01 ? 0 : left;
  }

  /// What clears the loan today. Paying early earns no discount: it costs
  /// exactly what is still owed.
  double get settlementAmount => figures?.settlementAmount ?? outstanding;

  double get repaymentProgress =>
      figures?.repaymentProgress ??
      (totalRepayable <= 0 ? 0 : (amountRepaid / totalRepayable).clamp(0.0, 1.0));

  bool get isOpen => status == LoanStatus.active || status == LoanStatus.overdue;

  /// The repayment schedule — the server's when it sent one, otherwise
  /// derived from what has actually been repaid so far: oldest first,
  /// covered → paid, partly → part paid, past its date and not covered →
  /// overdue.
  List<Installment> get schedule {
    final f = figures;
    if (f != null && f.schedule.isNotEmpty) return f.schedule;

    var covered = amountRepaid;
    final now = DateTime.now();
    final plan = _plan;

    return List.generate(plan.length, (i) {
      final each = plan[i].total;
      final due = frequency.due(disbursedAt, i + 1);
      final paidHere = covered >= each ? each : (covered > 0 ? covered : 0.0);
      covered -= paidHere;

      final settled = paidHere >= each - 0.01;
      return Installment(
        number: i + 1,
        dueDate: due,
        amount: each,
        amountPaid: paidHere,
        fee: plan[i].fee,
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

  /// "6 months, repaid monthly" or "26 weeks, repaid weekly".
  String get termPhrase =>
      '${frequency.length(tenureMonths, count: installmentCount)}, '
      'repaid ${frequency.adjective}';

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
    frequency: frequency,
    installmentCount: installmentCount,
    repaymentFeeRate: repaymentFeeRate,
    transactionFee: transactionFee,
    wholeNaira: wholeNaira,
    // The server's figures describe the loan as it was sent. A change made
    // here — only ever on a device with no server — is worked out afresh.
    figures: amountRepaid == null && status == null ? figures : null,
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
    'frequency': frequency.wire,
    'installmentCount': installmentCount,
    'repaymentFeeRate': repaymentFeeRate,
    'transactionFee': transactionFee,
    'wholeNaira': wholeNaira,
    if (figures != null) 'figures': figures!.toJson(),
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
    // Loans cached before weekly repayment and the transaction fee read as
    // what they were: monthly, with no fee, split to the kobo.
    frequency: RepaymentFrequency.fromWire(j['frequency']),
    installmentCount: j['installmentCount'] as int?,
    repaymentFeeRate: (j['repaymentFeeRate'] as num?)?.toDouble() ?? 0,
    transactionFee: (j['transactionFee'] as num?)?.toDouble() ?? 0,
    wholeNaira: j['wholeNaira'] as bool? ?? false,
    figures: LoanFigures.fromJson(j['figures']),
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
    this.fee = 0,
  });

  final int number;
  final DateTime dueDate;

  /// The whole instalment, transaction fee included.
  final double amount;
  final double amountPaid;
  final InstallmentStatus status;

  /// The transaction fee within [amount].
  final double fee;

  /// The share of the loan and interest, before the transaction fee.
  double get base => amount - fee;

  double get outstanding {
    final left = amount - amountPaid;
    return left < 0.01 ? 0 : left;
  }

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  Map<String, dynamic> toJson() => {
    'number': number,
    'dueDate': dueDate.toIso8601String(),
    'amount': amount,
    'amountPaid': amountPaid,
    'status': status.index,
    'fee': fee,
  };

  factory Installment.fromJson(Map<String, dynamic> j) => Installment(
    number: j['number'] as int? ?? 0,
    dueDate: DateTime.tryParse(j['dueDate'] as String? ?? '') ?? DateTime.now(),
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
    status: InstallmentStatus.values[(j['status'] as int? ?? 2)
        .clamp(0, InstallmentStatus.values.length - 1)],
    fee: (j['fee'] as num?)?.toDouble() ?? 0,
  );
}

// ── Transactions ──────────────────────────────────────────────────────────

enum TxKind {
  deposit,
  withdrawal,
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
enum TxFilter { all, deposits, withdrawals, savings, loans, fees }

extension TxFilterX on TxFilter {
  String get label => switch (this) {
    TxFilter.all => 'All',
    TxFilter.deposits => 'Deposits',
    TxFilter.withdrawals => 'Withdrawals',
    TxFilter.savings => 'Savings',
    TxFilter.loans => 'Loans',
    TxFilter.fees => 'Fees',
  };

  bool matches(Transaction tx) => switch (this) {
    TxFilter.all => true,
    TxFilter.deposits => tx.kind == TxKind.deposit,
    TxFilter.withdrawals => tx.kind == TxKind.withdrawal,
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
  /// The 17% p.a. return on a Fixed Savings principal locked for [days],
  /// paid into the wallet upfront.
  ///
  /// The annual rate is spread evenly across the year, so a lock of any
  /// length is priced exactly: 365 days pays the full 17%, 30 days pays
  /// 1.397%, and 171 days pays 7.964%. No rounding to whole months.
  static double savingsInterest(double principal, int days) =>
      principal * settings.savingsAnnualRate * (days / settings.daysPerYear);

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

  static double savingsTotal(double principal, int days) =>
      principal + savingsInterest(principal, days);

  /// Effective yield over the whole lock period, as a percentage.
  static double effectiveYieldPct(int days) =>
      settings.savingsAnnualRate * (days / settings.daysPerYear) * 100;

  /// Flat interest on the amount borrowed, at the rate published for a
  /// tenure of [months], rounded up to the naira as loans are now priced.
  static double loanInterest(double principal, int months, [LendingTerms? terms]) =>
      loanTotal(principal, months, terms) - principal;

  /// The loan and its interest, before the transaction fees — whole naira,
  /// rounded up.
  static double loanTotal(double principal, int months, [LendingTerms? terms]) =>
      principal <= 0
      ? 0
      : ceilNaira(principal * (1 + (terms ?? settings.lending).rateFor(months)));

  /// The management fee on a loan of [principal]: flat up to and including
  /// the threshold — ₦5,000 to ₦250,000 at the shipped setting — and a
  /// percentage of the whole principal, not of the excess, above it. The
  /// rules meet exactly at the threshold, so the fee curve is continuous.
  /// Always taken out of the disbursement.
  static double processingFee(double principal, [LendingTerms? terms]) =>
      (terms ?? settings.lending).processingFeeFor(principal);

  /// What actually reaches the wallet once the fee is taken off. Nothing else
  /// comes off: the transaction fee is paid with each repayment.
  static double netDisbursed(double principal, [LendingTerms? terms]) =>
      (terms ?? settings.lending).netDisbursedFor(principal);

  /// Human-readable description of how this loan's fee was worked out.
  static String processingFeeBasis(double principal, [LendingTerms? terms]) =>
      (terms ?? settings.lending).feeBasisFor(principal);

  /// Rounds up to the whole naira, ignoring floating-point dust — 10,417.000000001
  /// is 10,417, not 10,418.
  static double ceilNaira(double v) =>
      ((v * 1e6).roundToDouble() / 1e6).ceilToDouble();

  /// Splits the loan and interest into [count] instalments and puts the
  /// transaction fee on each.
  ///
  /// In whole naira, as loans are now priced: each share is the total divided
  /// equally and rounded **up** to the naira, the last takes whatever is left
  /// so the shares sum to the total exactly, and the fee on each is [feeRate]
  /// of its share, also rounded up. ₦125,000 over 12 weeks at 2% is ₦10,417 +
  /// ₦209 a week, the last ₦10,413 + ₦209. Loans priced before that were
  /// split to the kobo with no fee, and are split here exactly as they were.
  /// Mirrors `Finance.instalmentPlan` on the server.
  static List<InstalmentPart> instalmentPlan(
    double loanTotal,
    int count,
    double feeRate, {
    bool wholeNaira = true,
  }) {
    if (count <= 0) return const [];
    double round2(double v) => (v * 100).roundToDouble() / 100;
    var each = wholeNaira ? ceilNaira(loanTotal / count) : round2(loanTotal / count);
    var last = round2(loanTotal - each * (count - 1));
    if (wholeNaira && last <= 0) {
      // Only a tiny loan over very many weeks: rounding every share up would
      // leave nothing for the last, so round them down instead.
      each = (loanTotal / count).floorToDouble();
      last = round2(loanTotal - each * (count - 1));
    }
    return List.generate(count, (i) {
      final base = i == count - 1 ? last : each;
      final fee = wholeNaira ? ceilNaira(base * feeRate) : round2(base * feeRate);
      return InstalmentPart(base, fee);
    });
  }

  /// Everything a borrower should see before they ask for a loan, priced on
  /// [terms] — theirs, which for a member of a loan group are the group's.
  ///
  /// A preview. The server prices the application again and its answer is
  /// the one charged; this mirrors its arithmetic so the two agree.
  static LoanPreview loanPreview(
    double principal,
    int months, {
    RepaymentFrequency frequency = RepaymentFrequency.monthly,
    LendingTerms? terms,
    DateTime? start,
  }) {
    final t = terms ?? settings.lending;
    final rate = t.rateFor(months);
    final loanTotal = Finance.loanTotal(principal, months, t);
    final count = frequency.installments(months, start);
    final plan = instalmentPlan(loanTotal, count, t.repaymentFeeRate);
    final fees = plan.fold(0.0, (sum, p) => sum + p.fee);
    final first = plan.isEmpty ? const InstalmentPart(0, 0) : plan.first;
    final fee = principal > 0 ? t.processingFeeFor(principal) : 0.0;
    return LoanPreview(
      rate: rate,
      interest: (loanTotal - principal).clamp(0, double.infinity).toDouble(),
      loanTotal: loanTotal,
      fees: fees,
      total: loanTotal + fees,
      frequency: frequency,
      count: count,
      each: first.total,
      base: first.base,
      instalmentFee: first.fee,
      feeRate: t.repaymentFeeRate,
      fee: fee,
      net: principal - fee,
    );
  }

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

/// One instalment: its share of the loan and interest, and the transaction
/// fee on that share.
class InstalmentPart {
  const InstalmentPart(this.base, this.fee);
  final double base;
  final double fee;
  double get total => base + fee;
}

/// What a loan will cost, worked out before anyone asks for it.
class LoanPreview {
  const LoanPreview({
    required this.rate,
    required this.interest,
    required this.loanTotal,
    required this.fees,
    required this.total,
    required this.frequency,
    required this.count,
    required this.each,
    required this.base,
    required this.instalmentFee,
    required this.feeRate,
    required this.fee,
    required this.net,
  });

  /// The flat rate for the tenure.
  final double rate;

  /// Flat interest, whole naira, rounded up.
  final double interest;

  /// The loan and its interest, before the transaction fees.
  final double loanTotal;

  /// The transaction fee on every instalment, added up.
  final double fees;

  /// Everything repaid: the loan, the interest and every transaction fee.
  final double total;
  final RepaymentFrequency frequency;

  /// How many instalments.
  final int count;

  /// One instalment, fee included, and its two parts. The last can be a
  /// little smaller.
  final double each;
  final double base;
  final double instalmentFee;

  /// The transaction fee rate on each repayment: 0.02 for 2%.
  final double feeRate;

  /// The management fee — the only thing taken off the payout.
  final double fee;

  /// What reaches the wallet.
  final double net;
}
