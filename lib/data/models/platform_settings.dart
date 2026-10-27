import 'dart:math' as math;

import '../../core/constants/app_config.dart';

/// How often a borrower pays back: once a month, or once a week.
///
/// The tenure is still chosen in months and priced from the same rate card,
/// so the choice changes how the total is split, not what the loan costs.
/// Mirrors `RepaymentFrequency` on the server.
enum RepaymentFrequency {
  monthly,
  weekly;

  /// "MONTHLY" or "WEEKLY", as the server writes it.
  String get wire => name.toUpperCase();

  String get label => switch (this) {
    RepaymentFrequency.monthly => 'Monthly',
    RepaymentFrequency.weekly => 'Weekly',
  };

  /// "month" or "week", for "₦25,000 a week".
  String get unit => switch (this) {
    RepaymentFrequency.monthly => 'month',
    RepaymentFrequency.weekly => 'week',
  };

  /// "monthly" or "weekly", for running text.
  String get adjective => name;

  static RepaymentFrequency fromWire(Object? value) =>
      value is String && value.toUpperCase() == 'WEEKLY'
      ? RepaymentFrequency.weekly
      : RepaymentFrequency.monthly;

  /// How many instalments a tenure of [months] starting at [start] is split
  /// into: one a month, or one for each whole week the calendar holds between
  /// [start] and the same date [months] later — 13 for most three-month loans,
  /// 12 when the months are short. A loan fixes its count on the day it is
  /// paid out.
  int installments(int months, [DateTime? start]) {
    if (months <= 0) return 0;
    if (this == RepaymentFrequency.monthly) return months;
    final from = start ?? DateTime.now();
    final days = _addMonths(from, months).difference(from).inHours / 24;
    return math.max(1, days.round() ~/ 7);
  }

  /// When the [n]th instalment (counting from 1) falls due.
  DateTime due(DateTime disbursedAt, int n) => switch (this) {
    RepaymentFrequency.monthly => _addMonths(disbursedAt, n),
    RepaymentFrequency.weekly => disbursedAt.add(Duration(days: 7 * n)),
  };

  /// "12 months", or for a weekly loan the weeks those months hold:
  /// "52 weeks". [count] is a loan's fixed instalment count, when it has one.
  String length(int months, {int? count, DateTime? start}) {
    if (this == RepaymentFrequency.monthly) {
      return '$months ${months == 1 ? 'month' : 'months'}';
    }
    final weeks = count ?? installments(months, start);
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
  }

  /// "13 weekly payments" or "3 monthly payments".
  String paymentsPhrase(int months, {int? count, DateTime? start}) {
    final n = count ?? installments(months, start);
    return '$n $adjective payment${n == 1 ? '' : 's'}';
  }
}

DateTime _addMonths(DateTime from, int months) {
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

/// Everything that prices a loan, as one set.
///
/// There are two: the terms for everyone, and the terms for members of a loan
/// group, which an admin edits on their own. A quote, an application and a
/// disbursement all price from whichever set the borrower is on, so none of
/// the screens that show a figure has to know which it was handed.
/// Mirrors `LendingTerms` on the server.
class LendingTerms {
  const LendingTerms({
    this.group = false,
    this.rates = AppConfig.loanRatesByTenure,
    this.maxTenureMonths = AppConfig.maxLoanTenureMonths,
    this.minAmount = AppConfig.minLoanAmount,
    this.maxAmount = AppConfig.maxLoanAmount,
    this.flatProcessingFee = AppConfig.flatProcessingFee,
    this.processingFeeThreshold = AppConfig.processingFeeThreshold,
    this.processingFeeRate = AppConfig.loanProcessingFeeRate,
    this.repaymentFeeRate = AppConfig.loanRepaymentFeeRate,
    this.weeklyAllowed = true,
    this.monthlyAllowed = true,
  });

  /// True for the loan-group set.
  final bool group;

  /// Flat interest keyed by tenure in months.
  final Map<int, double> rates;
  final int maxTenureMonths;
  final double minAmount;
  final double maxAmount;
  final double flatProcessingFee;
  final double processingFeeThreshold;

  /// The management fee above the threshold, as a fraction of the whole loan.
  final double processingFeeRate;

  /// The transaction fee on each repayment, as a fraction of the instalment:
  /// 0.02 for 2%.
  final double repaymentFeeRate;
  final bool weeklyAllowed;
  final bool monthlyAllowed;

  /// "Loan group" or "Standard".
  String get label => group ? 'Loan group' : 'Standard';

  /// The flat rate for a loan of [months].
  ///
  /// A tenure with no entry of its own falls back to the nearest shorter
  /// tenure that does have one, so the table can never leave a loan unpriced.
  double rateFor(int months) {
    if (rates.isEmpty) return 0;
    final wanted = months < 1 ? 1 : months;
    final exact = rates[wanted];
    if (exact != null) return exact;

    var best = 0.0;
    var bestMonths = 0;
    rates.forEach((m, rate) {
      if (m <= wanted && m > bestMonths) {
        bestMonths = m;
        best = rate;
      }
    });
    if (bestMonths > 0) return best;

    // Nothing at or below the tenure asked for: take the shortest we have.
    final shortest = rates.keys.reduce((a, b) => a < b ? a : b);
    return rates[shortest]!;
  }

  /// The management fee on a loan of [principal]: flat up to **and
  /// including** the threshold, [processingFeeRate] of the **whole** amount
  /// above it — never of the excess.
  double processingFeeFor(double principal) => principal <= processingFeeThreshold
      ? flatProcessingFee
      : principal * processingFeeRate;

  /// What reaches the wallet: the loan less the management fee. Nothing else
  /// comes off — the transaction fee is paid with each repayment instead.
  double netDisbursedFor(double principal) =>
      principal - processingFeeFor(principal);

  /// How this loan's management fee was worked out, in words.
  String feeBasisFor(double principal) => principal <= processingFeeThreshold
      ? 'Flat fee up to ₦${_grouped(processingFeeThreshold)}'
      : '${PlatformSettings.ratePct(processingFeeRate * 100)} of the whole amount';

  /// "2%".
  String get repaymentFeeLabel => PlatformSettings.ratePct(repaymentFeeRate * 100);

  /// The tenures a borrower may choose.
  List<int> get tenures => List.generate(maxTenureMonths, (i) => i + 1);

  /// The ways of repaying this set offers, monthly first.
  List<RepaymentFrequency> get frequencies => [
    if (monthlyAllowed) RepaymentFrequency.monthly,
    if (weeklyAllowed) RepaymentFrequency.weekly,
  ];

  bool allows(RepaymentFrequency f) =>
      f == RepaymentFrequency.weekly ? weeklyAllowed : monthlyAllowed;

  /// "12.5-134%" — the span of the rate card.
  String get rateRange {
    if (rates.isEmpty) return '—';
    final pcts = tenures.map((m) => rateFor(m) * 100).toList()..sort();
    final low = PlatformSettings.ratePct(pcts.first);
    final high = PlatformSettings.ratePct(pcts.last);
    return low == high ? low : '${low.replaceAll('%', '')}-$high';
  }

  LendingTerms copyWith({
    Map<int, double>? rates,
    int? maxTenureMonths,
    double? minAmount,
    double? maxAmount,
    double? flatProcessingFee,
    double? processingFeeThreshold,
    double? processingFeeRate,
    double? repaymentFeeRate,
    bool? weeklyAllowed,
    bool? monthlyAllowed,
  }) => LendingTerms(
    group: group,
    rates: rates ?? this.rates,
    maxTenureMonths: maxTenureMonths ?? this.maxTenureMonths,
    minAmount: minAmount ?? this.minAmount,
    maxAmount: maxAmount ?? this.maxAmount,
    flatProcessingFee: flatProcessingFee ?? this.flatProcessingFee,
    processingFeeThreshold: processingFeeThreshold ?? this.processingFeeThreshold,
    processingFeeRate: processingFeeRate ?? this.processingFeeRate,
    repaymentFeeRate: repaymentFeeRate ?? this.repaymentFeeRate,
    weeklyAllowed: weeklyAllowed ?? this.weeklyAllowed,
    monthlyAllowed: monthlyAllowed ?? this.monthlyAllowed,
  );

  bool sameAs(LendingTerms o) =>
      _sameRates(rates, o.rates) &&
      maxTenureMonths == o.maxTenureMonths &&
      minAmount == o.minAmount &&
      maxAmount == o.maxAmount &&
      flatProcessingFee == o.flatProcessingFee &&
      processingFeeThreshold == o.processingFeeThreshold &&
      processingFeeRate == o.processingFeeRate &&
      repaymentFeeRate == o.repaymentFeeRate &&
      weeklyAllowed == o.weeklyAllowed &&
      monthlyAllowed == o.monthlyAllowed;

  /// The server's `Lending` record, as `/settings/public` and
  /// `/loans/eligibility` send it.
  static LendingTerms fromApi(Map<String, dynamic> j, {bool group = false}) =>
      LendingTerms(
        group: group,
        rates: _ratesFrom(j['rates']) ?? AppConfig.loanRatesByTenure,
        maxTenureMonths: _intOr(j['maxTenureMonths'], AppConfig.maxLoanTenureMonths),
        minAmount: _numOr(j['minAmount'], AppConfig.minLoanAmount),
        maxAmount: _numOr(j['maxAmount'], AppConfig.maxLoanAmount),
        flatProcessingFee: _numOr(j['flatProcessingFee'], AppConfig.flatProcessingFee),
        processingFeeThreshold:
            _numOr(j['processingFeeThreshold'], AppConfig.processingFeeThreshold),
        processingFeeRate: _numOr(j['processingFeeRate'], AppConfig.loanProcessingFeeRate),
        repaymentFeeRate: _numOr(j['repaymentFeeRate'], AppConfig.loanRepaymentFeeRate),
        weeklyAllowed: j['weeklyAllowed'] as bool? ?? true,
        monthlyAllowed: j['monthlyAllowed'] as bool? ?? true,
      );

  /// The flattened fields of the admin settings document, `group…` prefixed
  /// for the loan-group set.
  Map<String, dynamic> toSettingsJson() => group
      ? {
          'groupLoanRates': _ratesJson(rates),
          'groupMaxLoanTenureMonths': maxTenureMonths,
          'groupMinLoanAmount': minAmount,
          'groupMaxLoanAmount': maxAmount,
          'groupFlatProcessingFee': flatProcessingFee,
          'groupProcessingFeeThreshold': processingFeeThreshold,
          'groupLoanProcessingFeeRate': processingFeeRate,
          'groupLoanRepaymentFeeRate': repaymentFeeRate,
          'groupLoanWeeklyAllowed': weeklyAllowed,
          'groupLoanMonthlyAllowed': monthlyAllowed,
        }
      : {
          'loanRates': _ratesJson(rates),
          'maxLoanTenureMonths': maxTenureMonths,
          'minLoanAmount': minAmount,
          'maxLoanAmount': maxAmount,
          'flatProcessingFee': flatProcessingFee,
          'processingFeeThreshold': processingFeeThreshold,
          'loanProcessingFeeRate': processingFeeRate,
          'loanRepaymentFeeRate': repaymentFeeRate,
          'loanWeeklyAllowed': weeklyAllowed,
          'loanMonthlyAllowed': monthlyAllowed,
        };

  /// Reads the group set back out of a stored settings document. Null when
  /// the document predates group pricing.
  static LendingTerms? groupFromSettingsJson(Map<String, dynamic> j) {
    if (j['groupMaxLoanTenureMonths'] == null) return null;
    return LendingTerms(
      group: true,
      rates: _ratesFrom(j['groupLoanRates']) ?? AppConfig.loanRatesByTenure,
      maxTenureMonths: _intOr(j['groupMaxLoanTenureMonths'], AppConfig.maxLoanTenureMonths),
      minAmount: _numOr(j['groupMinLoanAmount'], AppConfig.minLoanAmount),
      maxAmount: _numOr(j['groupMaxLoanAmount'], AppConfig.maxLoanAmount),
      flatProcessingFee: _numOr(j['groupFlatProcessingFee'], AppConfig.flatProcessingFee),
      processingFeeThreshold:
          _numOr(j['groupProcessingFeeThreshold'], AppConfig.processingFeeThreshold),
      processingFeeRate:
          _numOr(j['groupLoanProcessingFeeRate'], AppConfig.loanProcessingFeeRate),
      repaymentFeeRate:
          _numOr(j['groupLoanRepaymentFeeRate'], AppConfig.loanRepaymentFeeRate),
      weeklyAllowed: j['groupLoanWeeklyAllowed'] as bool? ?? true,
      monthlyAllowed: j['groupLoanMonthlyAllowed'] as bool? ?? true,
    );
  }

  static Map<String, double> _ratesJson(Map<int, double> rates) => {
    for (final e in rates.entries) e.key.toString(): e.value,
  };

  static bool _sameRates(Map<int, double> a, Map<int, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}

/// The economics of Kudi9ja, as they can be tuned from the admin panel.
///
/// [AppConfig] holds the compiled-in defaults and the things admins must not
/// change (passcode lengths, app name). Everything a business decision can
/// move lives here, is read from the server's public settings, and is read at
/// runtime through [settings].
class PlatformSettings {
  const PlatformSettings({
    this.savingsAnnualRate = AppConfig.savingsAnnualRate,
    this.minLockDays = AppConfig.minLockDays,
    this.maxLockDays = AppConfig.maxLockDays,
    this.daysPerYear = AppConfig.daysPerYear,
    this.minSavingsAmount = AppConfig.minSavingsAmount,
    this.targetRateShort = AppConfig.targetRateShort,
    this.targetRateMedium = AppConfig.targetRateMedium,
    this.targetRateLong = AppConfig.targetRateLong,
    this.minTargetMonths = AppConfig.minTargetMonths,
    this.minLoanAmount = AppConfig.minLoanAmount,
    this.maxLoanAmount = AppConfig.maxLoanAmount,
    this.loanRates = AppConfig.loanRatesByTenure,
    this.maxLoanTenureMonths = AppConfig.maxLoanTenureMonths,
    this.flatProcessingFee = AppConfig.flatProcessingFee,
    this.processingFeeThreshold = AppConfig.processingFeeThreshold,
    this.loanProcessingFeeRate = AppConfig.loanProcessingFeeRate,
    this.loanRepaymentFeeRate = AppConfig.loanRepaymentFeeRate,
    this.loanWeeklyAllowed = true,
    this.loanMonthlyAllowed = true,
    this.groupLending = const LendingTerms(group: true),
    this.savingsEnabled = true,
    this.lendingEnabled = true,
    this.thriftEnabled = true,
    this.maintenanceMode = false,
    this.maxSavingsAmount = AppConfig.maxSavingsAmount,
    this.targetTierMedium = AppConfig.targetTierMedium,
    this.targetTierLong = AppConfig.targetTierLong,
    this.daysPerSavingsMonth = AppConfig.daysPerSavingsMonth,
    this.maxPasscodeAttempts = AppConfig.maxPasscodeAttempts,
    this.lockTimeoutMinutes = AppConfig.lockTimeoutMinutes,
    this.minDepositAmount = AppConfig.minDepositAmount,
    this.minWithdrawalAmount = AppConfig.minWithdrawalAmount,
    this.minCircleContribution = AppConfig.minCircleContribution,
    this.minCircleMembers = AppConfig.minCircleMembers,
    this.maxCircleMembers = AppConfig.maxCircleMembers,
    this.otpResendSeconds = AppConfig.otpResendSeconds,
    this.companyAccountName = AppConfig.companyAccountName,
    this.companyAccountNumber = AppConfig.companyAccountNumber,
    this.companyBank = AppConfig.companyBank,
    this.version,
  });

  // Savings ----------------------------------------------------------------
  final double savingsAnnualRate;
  /// Fixed Savings locks in days, not months.
  final int minLockDays;
  final int maxLockDays;

  /// The year the annual savings rate is spread over.
  final int daysPerYear;
  final double minSavingsAmount;
  final double targetRateShort;
  final double targetRateMedium;
  final double targetRateLong;
  final int minTargetMonths;

  // Lending ----------------------------------------------------------------
  final double minLoanAmount;
  final double maxLoanAmount;
  /// Flat interest keyed by tenure in months. Every selectable tenure has an
  /// entry, and the admin panel writes straight into this map.
  final Map<int, double> loanRates;
  final int maxLoanTenureMonths;
  final double flatProcessingFee;
  final double processingFeeThreshold;
  final double loanProcessingFeeRate;

  /// The transaction fee on every repayment, as a fraction of the instalment.
  final double loanRepaymentFeeRate;

  /// Whether borrowers may repay weekly, and monthly. At least one is on.
  final bool loanWeeklyAllowed;
  final bool loanMonthlyAllowed;

  /// What members of a loan group borrow on: their own copy of every number
  /// above, edited on its own.
  final LendingTerms groupLending;

  // Wallet & platform ------------------------------------------------------
  final bool savingsEnabled;
  final bool lendingEnabled;
  final bool thriftEnabled;
  final bool maintenanceMode;

  // Savings shape ----------------------------------------------------------
  final double maxSavingsAmount;

  /// The month boundaries the three Target bonus rates switch at.
  final int targetTierMedium;
  final int targetTierLong;

  /// A Target Savings month, in days.
  final int daysPerSavingsMonth;

  // Security ---------------------------------------------------------------
  final int maxPasscodeAttempts;

  /// Idle minutes before the app locks itself. Never below
  /// [AppConfig.minLockTimeoutMinutes].
  final int lockTimeoutMinutes;

  // Pay-in, payout and thrift ----------------------------------------------
  final double minDepositAmount;
  final double minWithdrawalAmount;
  final double minCircleContribution;
  final int minCircleMembers;
  final int maxCircleMembers;

  /// Seconds before a one-time code can be resent.
  final int otpResendSeconds;

  // Collection account -----------------------------------------------------
  final String companyAccountName;
  final String companyAccountNumber;
  final String companyBank;

  /// The server's version of these settings, when they came from it. What an
  /// admin's save is checked against, so two admins editing at once cannot
  /// silently overwrite each other.
  final int? version;

  /// The standard lending terms, as one set.
  LendingTerms get lending => LendingTerms(
    rates: loanRates,
    maxTenureMonths: maxLoanTenureMonths,
    minAmount: minLoanAmount,
    maxAmount: maxLoanAmount,
    flatProcessingFee: flatProcessingFee,
    processingFeeThreshold: processingFeeThreshold,
    processingFeeRate: loanProcessingFeeRate,
    repaymentFeeRate: loanRepaymentFeeRate,
    weeklyAllowed: loanWeeklyAllowed,
    monthlyAllowed: loanMonthlyAllowed,
  );

  /// A copy with the standard terms replaced as a set.
  PlatformSettings withLending(LendingTerms t) => copyWith(
    loanRates: t.rates,
    maxLoanTenureMonths: t.maxTenureMonths,
    minLoanAmount: t.minAmount,
    maxLoanAmount: t.maxAmount,
    flatProcessingFee: t.flatProcessingFee,
    processingFeeThreshold: t.processingFeeThreshold,
    loanProcessingFeeRate: t.processingFeeRate,
    loanRepaymentFeeRate: t.repaymentFeeRate,
    loanWeeklyAllowed: t.weeklyAllowed,
    loanMonthlyAllowed: t.monthlyAllowed,
  );

  /// The headline rate, as a percentage, for display.
  double get savingsRatePct => savingsAnnualRate * 100;

  /// The flat rate a loan of [months] is charged on the standard terms.
  double loanRateFor(int months) => lending.rateFor(months);

  /// A copy with the rate for a single tenure replaced — how the admin panel
  /// edits one row of the table without disturbing the others.
  PlatformSettings withLoanRate(int months, double rate) =>
      copyWith(loanRates: {...loanRates, months: rate});

  /// Whether two settings carry the same rate table. [copyWith] hands back a
  /// new map every time, so the admin screen cannot compare these with `!=`.
  bool sameLoanRatesAs(PlatformSettings other) =>
      LendingTerms._sameRates(loanRates, other.loanRates);

  double loanRatePctFor(int months) => loanRateFor(months) * 100;

  /// The management fee — also called the processing fee — on a loan of
  /// [principal], on the standard terms.
  double processingFeeFor(double principal) => lending.processingFeeFor(principal);

  /// What reaches the wallet once the fee is taken off.
  double netDisbursedFor(double principal) => lending.netDisbursedFor(principal);

  /// A rate for display: "17%", "12.5%" — never a rate rounded to "13%".
  /// Every surface that prints a rate goes through here, so a tier with a
  /// half point in it can never be quoted wrongly.
  static String ratePct(double pct) =>
      '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%';

  String loanRateLabelFor(int months) => ratePct(loanRatePctFor(months));

  /// "12.5-25%" — the span of the published tiers, for surfaces that
  /// advertise lending before a tenure has been chosen.
  String get loanRateRange => lending.rateRange;

  /// The tenures a customer may choose, capped by [maxLoanTenureMonths].
  List<int> get loanTenures =>
      List.generate(maxLoanTenureMonths, (i) => i + 1);
  double get targetShortPct => targetRateShort * 100;
  double get targetMediumPct => targetRateMedium * 100;
  double get targetLongPct => targetRateLong * 100;

  /// The bonus rate a plan of [months] earns.
  double targetRateFor(int months) {
    if (months >= targetTierLong) return targetRateLong;
    if (months >= targetTierMedium) return targetRateMedium;
    return targetRateShort;
  }

  double targetPctFor(int months) => targetRateFor(months) * 100;
  double get feeRatePct => loanProcessingFeeRate * 100;

  PlatformSettings copyWith({
    double? savingsAnnualRate,
    int? minLockDays,
    int? maxLockDays,
    int? daysPerYear,
    double? minSavingsAmount,
    double? targetRateShort,
    double? targetRateMedium,
    double? targetRateLong,
    int? minTargetMonths,
    double? minLoanAmount,
    double? maxLoanAmount,
    Map<int, double>? loanRates,
    int? maxLoanTenureMonths,
    double? flatProcessingFee,
    double? processingFeeThreshold,
    double? loanProcessingFeeRate,
    double? loanRepaymentFeeRate,
    bool? loanWeeklyAllowed,
    bool? loanMonthlyAllowed,
    LendingTerms? groupLending,
    bool? savingsEnabled,
    bool? lendingEnabled,
    bool? thriftEnabled,
    bool? maintenanceMode,
    double? maxSavingsAmount,
    int? targetTierMedium,
    int? targetTierLong,
    int? daysPerSavingsMonth,
    int? maxPasscodeAttempts,
    int? lockTimeoutMinutes,
    double? minDepositAmount,
    double? minWithdrawalAmount,
    double? minCircleContribution,
    int? minCircleMembers,
    int? maxCircleMembers,
    int? otpResendSeconds,
    String? companyAccountName,
    String? companyAccountNumber,
    String? companyBank,
    int? version,
  }) => PlatformSettings(
    savingsAnnualRate: savingsAnnualRate ?? this.savingsAnnualRate,
    minLockDays: minLockDays ?? this.minLockDays,
    maxLockDays: maxLockDays ?? this.maxLockDays,
    daysPerYear: daysPerYear ?? this.daysPerYear,
    minSavingsAmount: minSavingsAmount ?? this.minSavingsAmount,
    targetRateShort: targetRateShort ?? this.targetRateShort,
    targetRateMedium: targetRateMedium ?? this.targetRateMedium,
    targetRateLong: targetRateLong ?? this.targetRateLong,
    minTargetMonths: minTargetMonths ?? this.minTargetMonths,
    minLoanAmount: minLoanAmount ?? this.minLoanAmount,
    maxLoanAmount: maxLoanAmount ?? this.maxLoanAmount,
    loanRates: loanRates ?? this.loanRates,
    maxLoanTenureMonths: maxLoanTenureMonths ?? this.maxLoanTenureMonths,
    flatProcessingFee: flatProcessingFee ?? this.flatProcessingFee,
    processingFeeThreshold:
        processingFeeThreshold ?? this.processingFeeThreshold,
    loanProcessingFeeRate:
        loanProcessingFeeRate ?? this.loanProcessingFeeRate,
    loanRepaymentFeeRate: loanRepaymentFeeRate ?? this.loanRepaymentFeeRate,
    loanWeeklyAllowed: loanWeeklyAllowed ?? this.loanWeeklyAllowed,
    loanMonthlyAllowed: loanMonthlyAllowed ?? this.loanMonthlyAllowed,
    groupLending: groupLending ?? this.groupLending,
    savingsEnabled: savingsEnabled ?? this.savingsEnabled,
    lendingEnabled: lendingEnabled ?? this.lendingEnabled,
    thriftEnabled: thriftEnabled ?? this.thriftEnabled,
    maintenanceMode: maintenanceMode ?? this.maintenanceMode,
    maxSavingsAmount: maxSavingsAmount ?? this.maxSavingsAmount,
    targetTierMedium: targetTierMedium ?? this.targetTierMedium,
    targetTierLong: targetTierLong ?? this.targetTierLong,
    daysPerSavingsMonth: daysPerSavingsMonth ?? this.daysPerSavingsMonth,
    maxPasscodeAttempts: maxPasscodeAttempts ?? this.maxPasscodeAttempts,
    lockTimeoutMinutes: lockTimeoutMinutes ?? this.lockTimeoutMinutes,
    minDepositAmount: minDepositAmount ?? this.minDepositAmount,
    minWithdrawalAmount: minWithdrawalAmount ?? this.minWithdrawalAmount,
    minCircleContribution: minCircleContribution ?? this.minCircleContribution,
    minCircleMembers: minCircleMembers ?? this.minCircleMembers,
    maxCircleMembers: maxCircleMembers ?? this.maxCircleMembers,
    otpResendSeconds: otpResendSeconds ?? this.otpResendSeconds,
    companyAccountName: companyAccountName ?? this.companyAccountName,
    companyAccountNumber: companyAccountNumber ?? this.companyAccountNumber,
    companyBank: companyBank ?? this.companyBank,
    version: version ?? this.version,
  );

  /// The admin settings document, in the server's field names. Fields the
  /// server has retired are not written: the save overlays these on the live
  /// document, so leaving them out keeps whatever the server holds.
  Map<String, dynamic> toJson() => {
    'savingsAnnualRate': savingsAnnualRate,
    'minLockDays': minLockDays,
    'maxLockDays': maxLockDays,
    'daysPerYear': daysPerYear,
    'minSavingsAmount': minSavingsAmount,
    'targetRateShort': targetRateShort,
    'targetRateMedium': targetRateMedium,
    'targetRateLong': targetRateLong,
    'minTargetMonths': minTargetMonths,
    ...lending.toSettingsJson(),
    ...groupLending.toSettingsJson(),
    'savingsEnabled': savingsEnabled,
    'lendingEnabled': lendingEnabled,
    'thriftEnabled': thriftEnabled,
    'maintenanceMode': maintenanceMode,
    'maxSavingsAmount': maxSavingsAmount,
    'targetTierMedium': targetTierMedium,
    'targetTierLong': targetTierLong,
    'daysPerSavingsMonth': daysPerSavingsMonth,
    'maxPasscodeAttempts': maxPasscodeAttempts,
    'lockTimeoutMinutes': lockTimeoutMinutes,
    'minDepositAmount': minDepositAmount,
    'minWithdrawalAmount': minWithdrawalAmount,
    'minCircleContribution': minCircleContribution,
    'minCircleMembers': minCircleMembers,
    'maxCircleMembers': maxCircleMembers,
    'otpResendSeconds': otpResendSeconds,
    'companyAccountName': companyAccountName,
    'companyAccountNumber': companyAccountNumber,
    'companyBank': companyBank,
    if (version != null) 'version': version,
  };

  factory PlatformSettings.fromJson(Map<String, dynamic> j) => PlatformSettings(
    savingsAnnualRate:
        (j['savingsAnnualRate'] as num?)?.toDouble() ??
        AppConfig.savingsAnnualRate,
    // Settings saved when locks were counted in months are converted at
    // 365/12 days a month, which turns the old 1-month floor into 30 days
    // and the old 60-month ceiling into exactly 1,825.
    minLockDays: j['minLockDays'] as int? ?? _daysFromMonths(j['minLockMonths'])
        ?? AppConfig.minLockDays,
    maxLockDays: j['maxLockDays'] as int? ?? _daysFromMonths(j['maxLockMonths'])
        ?? AppConfig.maxLockDays,
    daysPerYear: j['daysPerYear'] as int? ?? AppConfig.daysPerYear,
    minSavingsAmount:
        (j['minSavingsAmount'] as num?)?.toDouble() ??
        AppConfig.minSavingsAmount,
    targetRateShort:
        (j['targetRateShort'] as num?)?.toDouble() ??
        AppConfig.targetRateShort,
    targetRateMedium:
        (j['targetRateMedium'] as num?)?.toDouble() ??
        AppConfig.targetRateMedium,
    targetRateLong:
        (j['targetRateLong'] as num?)?.toDouble() ?? AppConfig.targetRateLong,
    minTargetMonths:
        j['minTargetMonths'] as int? ?? AppConfig.minTargetMonths,
    minLoanAmount:
        (j['minLoanAmount'] as num?)?.toDouble() ?? AppConfig.minLoanAmount,
    maxLoanAmount:
        (j['maxLoanAmount'] as num?)?.toDouble() ?? AppConfig.maxLoanAmount,
    loanRates: _ratesFromJson(j),
    maxLoanTenureMonths:
        j['maxLoanTenureMonths'] as int? ?? AppConfig.maxLoanTenureMonths,
    flatProcessingFee:
        (j['flatProcessingFee'] as num?)?.toDouble() ??
        AppConfig.flatProcessingFee,
    processingFeeThreshold:
        (j['processingFeeThreshold'] as num?)?.toDouble() ??
        AppConfig.processingFeeThreshold,
    loanProcessingFeeRate:
        (j['loanProcessingFeeRate'] as num?)?.toDouble() ??
        AppConfig.loanProcessingFeeRate,
    loanRepaymentFeeRate:
        (j['loanRepaymentFeeRate'] as num?)?.toDouble() ??
        AppConfig.loanRepaymentFeeRate,
    loanWeeklyAllowed: j['loanWeeklyAllowed'] as bool? ?? true,
    loanMonthlyAllowed: j['loanMonthlyAllowed'] as bool? ?? true,
    groupLending:
        LendingTerms.groupFromSettingsJson(j) ?? const LendingTerms(group: true),
    savingsEnabled: j['savingsEnabled'] as bool? ?? true,
    lendingEnabled: j['lendingEnabled'] as bool? ?? true,
    thriftEnabled: j['thriftEnabled'] as bool? ?? true,
    maintenanceMode: j['maintenanceMode'] as bool? ?? false,
    maxSavingsAmount:
        (j['maxSavingsAmount'] as num?)?.toDouble() ?? AppConfig.maxSavingsAmount,
    targetTierMedium: j['targetTierMedium'] as int? ?? AppConfig.targetTierMedium,
    targetTierLong: j['targetTierLong'] as int? ?? AppConfig.targetTierLong,
    daysPerSavingsMonth: j['daysPerSavingsMonth'] as int? ?? AppConfig.daysPerSavingsMonth,
    maxPasscodeAttempts: j['maxPasscodeAttempts'] as int? ?? AppConfig.maxPasscodeAttempts,
    lockTimeoutMinutes: math.max(
      j['lockTimeoutMinutes'] as int? ?? AppConfig.lockTimeoutMinutes,
      AppConfig.minLockTimeoutMinutes,
    ),
    minDepositAmount:
        (j['minDepositAmount'] as num?)?.toDouble() ?? AppConfig.minDepositAmount,
    minWithdrawalAmount:
        (j['minWithdrawalAmount'] as num?)?.toDouble() ?? AppConfig.minWithdrawalAmount,
    minCircleContribution:
        (j['minCircleContribution'] as num?)?.toDouble() ?? AppConfig.minCircleContribution,
    minCircleMembers: j['minCircleMembers'] as int? ?? AppConfig.minCircleMembers,
    maxCircleMembers: j['maxCircleMembers'] as int? ?? AppConfig.maxCircleMembers,
    otpResendSeconds: j['otpResendSeconds'] as int? ?? AppConfig.otpResendSeconds,
    companyAccountName:
        j['companyAccountName'] as String? ?? AppConfig.companyAccountName,
    companyAccountNumber:
        j['companyAccountNumber'] as String? ?? AppConfig.companyAccountNumber,
    companyBank: j['companyBank'] as String? ?? AppConfig.companyBank,
    version: (j['version'] as num?)?.toInt(),
  );

  /// Reads `GET /settings/public`: the rates and limits every customer is
  /// priced on, grouped as the server groups them.
  ///
  /// The app used to quote from the figures compiled into it, so a rate an
  /// admin changed on the server was never the one a customer was shown — and
  /// the management fee threshold went on reading ₦500,000 long after it had
  /// become ₦250,000. A field missing here keeps the compiled-in value rather
  /// than reading as zero.
  factory PlatformSettings.fromPublicApi(Map<String, dynamic> j) {
    Map<String, dynamic> obj(Object? v) =>
        v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
    final savings = obj(j['savings']);
    final lending = LendingTerms.fromApi(obj(j['lending']));
    final group = j['groupLending'] is Map
        ? LendingTerms.fromApi(obj(j['groupLending']), group: true)
        : lending.asGroup;
    final wallet = obj(j['wallet']);
    final thrift = obj(j['thrift']);
    final account = obj(j['collectionAccount']);
    final switches = obj(j['switches']);
    final security = obj(j['security']);

    return PlatformSettings(
      savingsAnnualRate: _numOr(savings['annualRate'], AppConfig.savingsAnnualRate),
      minLockDays: _intOr(savings['minLockDays'], AppConfig.minLockDays),
      maxLockDays: _intOr(savings['maxLockDays'], AppConfig.maxLockDays),
      daysPerYear: _intOr(savings['daysPerYear'], AppConfig.daysPerYear),
      minSavingsAmount: _numOr(savings['minAmount'], AppConfig.minSavingsAmount),
      maxSavingsAmount: _numOr(savings['maxAmount'], AppConfig.maxSavingsAmount),
      targetRateShort: _numOr(savings['targetRateShort'], AppConfig.targetRateShort),
      targetRateMedium: _numOr(savings['targetRateMedium'], AppConfig.targetRateMedium),
      targetRateLong: _numOr(savings['targetRateLong'], AppConfig.targetRateLong),
      targetTierMedium: _intOr(savings['targetTierMedium'], AppConfig.targetTierMedium),
      targetTierLong: _intOr(savings['targetTierLong'], AppConfig.targetTierLong),
      minTargetMonths: _intOr(savings['minTargetMonths'], AppConfig.minTargetMonths),
      daysPerSavingsMonth:
          _intOr(savings['daysPerSavingsMonth'], AppConfig.daysPerSavingsMonth),
      groupLending: group,
      minDepositAmount: _numOr(wallet['minDepositAmount'], AppConfig.minDepositAmount),
      minWithdrawalAmount:
          _numOr(wallet['minWithdrawalAmount'], AppConfig.minWithdrawalAmount),
      minCircleContribution:
          _numOr(thrift['minContribution'], AppConfig.minCircleContribution),
      minCircleMembers: _intOr(thrift['minMembers'], AppConfig.minCircleMembers),
      maxCircleMembers: _intOr(thrift['maxMembers'], AppConfig.maxCircleMembers),
      companyBank: _strOr(account['bank'], AppConfig.companyBank),
      companyAccountNumber: _strOr(account['accountNumber'], AppConfig.companyAccountNumber),
      companyAccountName: _strOr(account['accountName'], AppConfig.companyAccountName),
      savingsEnabled: switches['savingsEnabled'] as bool? ?? true,
      lendingEnabled: switches['lendingEnabled'] as bool? ?? true,
      thriftEnabled: switches['thriftEnabled'] as bool? ?? true,
      maintenanceMode: switches['maintenanceMode'] as bool? ?? false,
      maxPasscodeAttempts:
          _intOr(security['maxPasscodeAttempts'], AppConfig.maxPasscodeAttempts),
      lockTimeoutMinutes: math.max(
        _intOr(security['lockTimeoutMinutes'], AppConfig.lockTimeoutMinutes),
        AppConfig.minLockTimeoutMinutes,
      ),
      otpResendSeconds: _intOr(security['otpResendSeconds'], AppConfig.otpResendSeconds),
      version: (j['version'] as num?)?.toInt(),
    ).withLending(lending);
  }
}

extension on LendingTerms {
  /// The same numbers, labelled as the loan-group set.
  LendingTerms get asGroup => LendingTerms(
    group: true,
    rates: rates,
    maxTenureMonths: maxTenureMonths,
    minAmount: minAmount,
    maxAmount: maxAmount,
    flatProcessingFee: flatProcessingFee,
    processingFeeThreshold: processingFeeThreshold,
    processingFeeRate: processingFeeRate,
    repaymentFeeRate: repaymentFeeRate,
    weeklyAllowed: weeklyAllowed,
    monthlyAllowed: monthlyAllowed,
  );
}

double _numOr(Object? v, double fallback) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s) ?? fallback,
  _ => fallback,
};

int _intOr(Object? v, int fallback) => switch (v) {
  num n => n.toInt(),
  String s => int.tryParse(s) ?? fallback,
  _ => fallback,
};

String _strOr(Object? v, String fallback) =>
    v is String && v.trim().isNotEmpty ? v : fallback;

String _grouped(double v) {
  final whole = v.round().toString();
  return whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

/// A rate table off the wire, keyed by tenure. Null when there is none.
Map<int, double>? _ratesFrom(Object? table) {
  if (table is! Map) return null;
  final parsed = <int, double>{};
  table.forEach((key, value) {
    final months = int.tryParse('$key');
    if (months != null && value is num) parsed[months] = value.toDouble();
  });
  return parsed.isEmpty ? null : parsed;
}

/// Converts a stored month count to days, for settings written before Fixed
/// Savings locked in days. Returns null when there was no month value.
int? _daysFromMonths(Object? months) => months is num
    ? (months * AppConfig.daysPerYear / 12).round()
    : null;

/// Rebuilds the rate table from stored JSON, migrating the two earlier
/// shapes so an upgrade never silently reprices a lender's book:
///
///   * `loanRates`     — the current table, keyed by tenure.
///   * `loanRate1Month` / `loanRate2Months` / `loanRate3Months` — the three
///     fixed tiers that came before it.
///   * `loanFlatRate`  — one rate at every tenure, before tiering at all.
Map<int, double> _ratesFromJson(Map<String, dynamic> j) {
  final parsed = _ratesFrom(j['loanRates']);
  if (parsed != null) return parsed;

  final flat = (j['loanFlatRate'] as num?)?.toDouble();
  final legacy = <int, double?>{
    1: (j['loanRate1Month'] as num?)?.toDouble() ?? flat,
    2: (j['loanRate2Months'] as num?)?.toDouble() ?? flat,
    3: (j['loanRate3Months'] as num?)?.toDouble() ?? flat,
  };
  if (legacy.values.every((v) => v == null)) {
    return AppConfig.loanRatesByTenure;
  }

  // Keep the compiled-in table for every tenure the old settings never knew
  // about, and let what the admin had actually chosen win for 1, 2 and 3.
  return {
    ...AppConfig.loanRatesByTenure,
    for (final e in legacy.entries)
      if (e.value != null) e.key: e.value!,
  };
}

PlatformSettings _current = const PlatformSettings();

/// The live platform settings. Every rate calculation and limit check reads
/// through here, so an admin change takes effect app-wide immediately.
PlatformSettings get settings => _current;

void applySettings(PlatformSettings next) => _current = next;
