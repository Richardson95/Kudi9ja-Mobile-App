import '../../core/constants/app_config.dart';

/// The economics of Kudi9ja, as they can be tuned from the admin panel.
///
/// [AppConfig] holds the compiled-in defaults and the things admins must not
/// change (passcode lengths, app name). Everything a business decision can
/// move lives here, is persisted, and is read at runtime through [settings].
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
    this.savingsEnabled = true,
    this.lendingEnabled = true,
    this.thriftEnabled = true,
    this.maintenanceMode = false,
    this.maxSavingsAmount = AppConfig.maxSavingsAmount,
    this.targetTierMedium = AppConfig.targetTierMedium,
    this.targetTierLong = AppConfig.targetTierLong,
    this.daysPerSavingsMonth = AppConfig.daysPerSavingsMonth,
    this.earlyPayoffRebateShare = AppConfig.earlyPayoffRebateShare,
    this.loanBaseCap = AppConfig.loanBaseCap,
    this.loanSavingsMultiple = AppConfig.loanSavingsMultiple,
    this.loanScoreBaseline = AppConfig.loanScoreBaseline,
    this.loanScorePerPoint = AppConfig.loanScorePerPoint,
    this.loanOfferRounding = AppConfig.loanOfferRounding,
    this.creditBaseScore = AppConfig.creditBaseScore,
    this.creditPointsPerPlan = AppConfig.creditPointsPerPlan,
    this.creditPlanPointsCap = AppConfig.creditPlanPointsCap,
    this.creditNairaPerSavingsPoint = AppConfig.creditNairaPerSavingsPoint,
    this.creditSavingsPointsCap = AppConfig.creditSavingsPointsCap,
    this.creditPointsPerRepaidLoan = AppConfig.creditPointsPerRepaidLoan,
    this.creditRepaidPointsCap = AppConfig.creditRepaidPointsCap,
    this.creditOverduePenalty = AppConfig.creditOverduePenalty,
    this.creditVerifiedBonus = AppConfig.creditVerifiedBonus,
    this.creditScoreFloor = AppConfig.creditScoreFloor,
    this.creditScoreCeiling = AppConfig.creditScoreCeiling,
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

  // Lending shape ----------------------------------------------------------
  /// The share of the untouched months' interest handed back on an early
  /// settlement.
  final double earlyPayoffRebateShare;

  /// How a customer's offer is built, before [maxLoanAmount] caps it.
  final double loanBaseCap;
  final double loanSavingsMultiple;
  final int loanScoreBaseline;
  final double loanScorePerPoint;
  final double loanOfferRounding;

  // Credit score -----------------------------------------------------------
  final int creditBaseScore;
  final int creditPointsPerPlan;
  final int creditPlanPointsCap;
  final double creditNairaPerSavingsPoint;
  final int creditSavingsPointsCap;
  final int creditPointsPerRepaidLoan;
  final int creditRepaidPointsCap;
  final int creditOverduePenalty;
  final int creditVerifiedBonus;
  final int creditScoreFloor;
  final int creditScoreCeiling;

  // Security ---------------------------------------------------------------
  final int maxPasscodeAttempts;

  /// Idle minutes before the app locks itself.
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

  /// The headline rate, as a percentage, for display.
  double get savingsRatePct => savingsAnnualRate * 100;

  /// The flat rate a loan of [months] is charged.
  ///
  /// A tenure with no entry of its own falls back to the nearest shorter
  /// tenure that does have one, so the table can never leave a loan unpriced.
  /// Every tenure the app offers should still be set explicitly.
  double loanRateFor(int months) {
    final wanted = months < 1 ? 1 : months;
    final exact = loanRates[wanted];
    if (exact != null) return exact;

    var best = 0.0;
    var bestMonths = 0;
    loanRates.forEach((m, rate) {
      if (m <= wanted && m > bestMonths) {
        bestMonths = m;
        best = rate;
      }
    });
    if (bestMonths > 0) return best;

    // Nothing at or below the tenure asked for: take the shortest we have.
    final shortest = loanRates.keys.reduce((a, b) => a < b ? a : b);
    return loanRates[shortest]!;
  }

  /// A copy with the rate for a single tenure replaced — how the admin panel
  /// edits one row of the table without disturbing the others.
  PlatformSettings withLoanRate(int months, double rate) =>
      copyWith(loanRates: {...loanRates, months: rate});

  /// Whether two settings carry the same rate table. [copyWith] hands back a
  /// new map every time, so the admin screen cannot compare these with `!=`.
  bool sameLoanRatesAs(PlatformSettings other) {
    if (loanRates.length != other.loanRates.length) return false;
    for (final entry in loanRates.entries) {
      if (other.loanRates[entry.key] != entry.value) return false;
    }
    return true;
  }

  double loanRatePctFor(int months) => loanRateFor(months) * 100;

  /// The management fee — also called the processing fee — on a loan of
  /// [principal].
  ///
  /// A flat [flatProcessingFee] up to **and including**
  /// [processingFeeThreshold]. One naira above it, the fee becomes
  /// [loanProcessingFeeRate] of the **whole** amount borrowed, never of the
  /// excess over the threshold.
  ///
  /// The rule lives here, on the settings that parameterise it, so the admin
  /// panel can price a draft the customer has not been given yet and still be
  /// charging exactly what [Finance.processingFee] will charge.
  double processingFeeFor(double principal) =>
      principal <= processingFeeThreshold
      ? flatProcessingFee
      : principal * loanProcessingFeeRate;

  /// What reaches the wallet once the fee is taken off.
  double netDisbursedFor(double principal) =>
      principal - processingFeeFor(principal);

  /// A rate for display: "17%", "12.5%" — never a rate rounded to "13%".
  /// Every surface that prints a rate goes through here, so a tier with a
  /// half point in it can never be quoted wrongly.
  static String ratePct(double pct) =>
      '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%';

  String loanRateLabelFor(int months) => ratePct(loanRatePctFor(months));

  /// "12.5-25%" — the span of the published tiers, for surfaces that
  /// advertise lending before a tenure has been chosen.
  String get loanRateRange {
    final rates = loanTenures.map(loanRatePctFor).toList()..sort();
    final low = ratePct(rates.first);
    final high = ratePct(rates.last);
    return low == high ? low : '${low.replaceAll('%', '')}-$high';
  }

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
    bool? savingsEnabled,
    bool? lendingEnabled,
    bool? thriftEnabled,
    bool? maintenanceMode,
    double? maxSavingsAmount,
    int? targetTierMedium,
    int? targetTierLong,
    int? daysPerSavingsMonth,
    double? earlyPayoffRebateShare,
    double? loanBaseCap,
    double? loanSavingsMultiple,
    int? loanScoreBaseline,
    double? loanScorePerPoint,
    double? loanOfferRounding,
    int? creditBaseScore,
    int? creditPointsPerPlan,
    int? creditPlanPointsCap,
    double? creditNairaPerSavingsPoint,
    int? creditSavingsPointsCap,
    int? creditPointsPerRepaidLoan,
    int? creditRepaidPointsCap,
    int? creditOverduePenalty,
    int? creditVerifiedBonus,
    int? creditScoreFloor,
    int? creditScoreCeiling,
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
    savingsEnabled: savingsEnabled ?? this.savingsEnabled,
    lendingEnabled: lendingEnabled ?? this.lendingEnabled,
    thriftEnabled: thriftEnabled ?? this.thriftEnabled,
    maintenanceMode: maintenanceMode ?? this.maintenanceMode,
    maxSavingsAmount: maxSavingsAmount ?? this.maxSavingsAmount,
    targetTierMedium: targetTierMedium ?? this.targetTierMedium,
    targetTierLong: targetTierLong ?? this.targetTierLong,
    daysPerSavingsMonth: daysPerSavingsMonth ?? this.daysPerSavingsMonth,
    earlyPayoffRebateShare: earlyPayoffRebateShare ?? this.earlyPayoffRebateShare,
    loanBaseCap: loanBaseCap ?? this.loanBaseCap,
    loanSavingsMultiple: loanSavingsMultiple ?? this.loanSavingsMultiple,
    loanScoreBaseline: loanScoreBaseline ?? this.loanScoreBaseline,
    loanScorePerPoint: loanScorePerPoint ?? this.loanScorePerPoint,
    loanOfferRounding: loanOfferRounding ?? this.loanOfferRounding,
    creditBaseScore: creditBaseScore ?? this.creditBaseScore,
    creditPointsPerPlan: creditPointsPerPlan ?? this.creditPointsPerPlan,
    creditPlanPointsCap: creditPlanPointsCap ?? this.creditPlanPointsCap,
    creditNairaPerSavingsPoint: creditNairaPerSavingsPoint ?? this.creditNairaPerSavingsPoint,
    creditSavingsPointsCap: creditSavingsPointsCap ?? this.creditSavingsPointsCap,
    creditPointsPerRepaidLoan: creditPointsPerRepaidLoan ?? this.creditPointsPerRepaidLoan,
    creditRepaidPointsCap: creditRepaidPointsCap ?? this.creditRepaidPointsCap,
    creditOverduePenalty: creditOverduePenalty ?? this.creditOverduePenalty,
    creditVerifiedBonus: creditVerifiedBonus ?? this.creditVerifiedBonus,
    creditScoreFloor: creditScoreFloor ?? this.creditScoreFloor,
    creditScoreCeiling: creditScoreCeiling ?? this.creditScoreCeiling,
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
  );

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
    'minLoanAmount': minLoanAmount,
    'maxLoanAmount': maxLoanAmount,
    // JSON object keys must be strings, so the tenure is written as one.
    'loanRates': {
      for (final e in loanRates.entries) e.key.toString(): e.value,
    },
    'maxLoanTenureMonths': maxLoanTenureMonths,
    'flatProcessingFee': flatProcessingFee,
    'processingFeeThreshold': processingFeeThreshold,
    'loanProcessingFeeRate': loanProcessingFeeRate,
    'savingsEnabled': savingsEnabled,
    'lendingEnabled': lendingEnabled,
    'thriftEnabled': thriftEnabled,
    'maintenanceMode': maintenanceMode,
    'maxSavingsAmount': maxSavingsAmount,
    'targetTierMedium': targetTierMedium,
    'targetTierLong': targetTierLong,
    'daysPerSavingsMonth': daysPerSavingsMonth,
    'earlyPayoffRebateShare': earlyPayoffRebateShare,
    'loanBaseCap': loanBaseCap,
    'loanSavingsMultiple': loanSavingsMultiple,
    'loanScoreBaseline': loanScoreBaseline,
    'loanScorePerPoint': loanScorePerPoint,
    'loanOfferRounding': loanOfferRounding,
    'creditBaseScore': creditBaseScore,
    'creditPointsPerPlan': creditPointsPerPlan,
    'creditPlanPointsCap': creditPlanPointsCap,
    'creditNairaPerSavingsPoint': creditNairaPerSavingsPoint,
    'creditSavingsPointsCap': creditSavingsPointsCap,
    'creditPointsPerRepaidLoan': creditPointsPerRepaidLoan,
    'creditRepaidPointsCap': creditRepaidPointsCap,
    'creditOverduePenalty': creditOverduePenalty,
    'creditVerifiedBonus': creditVerifiedBonus,
    'creditScoreFloor': creditScoreFloor,
    'creditScoreCeiling': creditScoreCeiling,
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
    savingsEnabled: j['savingsEnabled'] as bool? ?? true,
    lendingEnabled: j['lendingEnabled'] as bool? ?? true,
    thriftEnabled: j['thriftEnabled'] as bool? ?? true,
    maintenanceMode: j['maintenanceMode'] as bool? ?? false,
    maxSavingsAmount:
        (j['maxSavingsAmount'] as num?)?.toDouble() ?? AppConfig.maxSavingsAmount,
    targetTierMedium: j['targetTierMedium'] as int? ?? AppConfig.targetTierMedium,
    targetTierLong: j['targetTierLong'] as int? ?? AppConfig.targetTierLong,
    daysPerSavingsMonth: j['daysPerSavingsMonth'] as int? ?? AppConfig.daysPerSavingsMonth,
    earlyPayoffRebateShare:
        (j['earlyPayoffRebateShare'] as num?)?.toDouble() ?? AppConfig.earlyPayoffRebateShare,
    loanBaseCap:
        (j['loanBaseCap'] as num?)?.toDouble() ?? AppConfig.loanBaseCap,
    loanSavingsMultiple:
        (j['loanSavingsMultiple'] as num?)?.toDouble() ?? AppConfig.loanSavingsMultiple,
    loanScoreBaseline: j['loanScoreBaseline'] as int? ?? AppConfig.loanScoreBaseline,
    loanScorePerPoint:
        (j['loanScorePerPoint'] as num?)?.toDouble() ?? AppConfig.loanScorePerPoint,
    loanOfferRounding:
        (j['loanOfferRounding'] as num?)?.toDouble() ?? AppConfig.loanOfferRounding,
    creditBaseScore: j['creditBaseScore'] as int? ?? AppConfig.creditBaseScore,
    creditPointsPerPlan: j['creditPointsPerPlan'] as int? ?? AppConfig.creditPointsPerPlan,
    creditPlanPointsCap: j['creditPlanPointsCap'] as int? ?? AppConfig.creditPlanPointsCap,
    creditNairaPerSavingsPoint:
        (j['creditNairaPerSavingsPoint'] as num?)?.toDouble() ?? AppConfig.creditNairaPerSavingsPoint,
    creditSavingsPointsCap: j['creditSavingsPointsCap'] as int? ?? AppConfig.creditSavingsPointsCap,
    creditPointsPerRepaidLoan: j['creditPointsPerRepaidLoan'] as int? ?? AppConfig.creditPointsPerRepaidLoan,
    creditRepaidPointsCap: j['creditRepaidPointsCap'] as int? ?? AppConfig.creditRepaidPointsCap,
    creditOverduePenalty: j['creditOverduePenalty'] as int? ?? AppConfig.creditOverduePenalty,
    creditVerifiedBonus: j['creditVerifiedBonus'] as int? ?? AppConfig.creditVerifiedBonus,
    creditScoreFloor: j['creditScoreFloor'] as int? ?? AppConfig.creditScoreFloor,
    creditScoreCeiling: j['creditScoreCeiling'] as int? ?? AppConfig.creditScoreCeiling,
    maxPasscodeAttempts: j['maxPasscodeAttempts'] as int? ?? AppConfig.maxPasscodeAttempts,
    lockTimeoutMinutes: j['lockTimeoutMinutes'] as int? ?? AppConfig.lockTimeoutMinutes,
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
  );
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
  final table = j['loanRates'];
  if (table is Map) {
    final parsed = <int, double>{};
    table.forEach((key, value) {
      final months = int.tryParse('$key');
      if (months != null && value is num) parsed[months] = value.toDouble();
    });
    if (parsed.isNotEmpty) return parsed;
  }

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
