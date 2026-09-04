/// Product rules for Kudi9ja. Single source of truth for every calculation.
abstract final class AppConfig {
  static const appName = 'Kudi9ja';
  static const tagline = 'Pay smart. Pay global.';

  // Savings ----------------------------------------------------------------
  /// Annual return on locked savings, paid to the wallet the moment the
  /// plan is created.
  static const savingsAnnualRate = 0.17;
  static const minLockMonths = 1;
  static const maxLockMonths = 60; // 5 years
  static const minSavingsAmount = 5000.0;
  static const maxSavingsAmount = 50000000.0;

  /// Target Savings pays a bonus on the final day, and the rate depends on
  /// how long the customer committed for. Longer terms are rewarded.
  ///   3 - 5 months   2.5%
  ///   6 - 11 months  5%
  ///   12 months up   10%
  static const targetRateShort = 0.025;
  static const targetRateMedium = 0.05;
  static const targetRateLong = 0.10;

  /// The month boundaries those three rates switch at.
  static const targetTierMedium = 6;
  static const targetTierLong = 12;

  /// Half the interest on the months a loan never ran is given back when a
  /// borrower settles early. 0.5 is that half.
  static const earlyPayoffRebateShare = 0.5;

  /// Target Savings must run for at least this long.
  static const minTargetMonths = 3;

  /// Target Savings counts a month as 30 days, so 6 months is 180 days.
  static const daysPerSavingsMonth = 30;

  // Lending ----------------------------------------------------------------
  static const maxLoanAmount = 5000000.0;
  static const minLoanAmount = 50000.0;
  /// Flat interest by tenure, in months. Every tenure the app offers has its
  /// own rate here, and an admin can change any of them from the panel — the
  /// rate for a 7-month loan is as editable as the rate for a 1-month one.
  ///
  /// The charge is flat: it is worked out once on the amount borrowed, never
  /// compounds, and never grows. Only the tenure moves it.
  ///
  /// The card is built on two rules, and both hold at every step:
  ///
  ///   * **The total always rises with the tenure**, so nobody is ever better
  ///     off borrowing for longer than they need.
  ///   * **The cost per month always falls** — 12.50 a month at one month,
  ///     8.33 at three, 6.50 at twelve, 5.58 at twenty-four — because the
  ///     fixed cost of writing a loan spreads over more months.
  ///
  /// Months 1 to 3 are the published rate card. Months 4 to 24 continue its
  /// curve and are provisional: reasonable, and deliberately shaped, but set
  /// them from the admin panel before they are lent against in anger.
  static const loanRatesByTenure = <int, double>{
    1: 0.125,
    2: 0.17,
    3: 0.25,
    4: 0.32,
    5: 0.38,
    6: 0.45,
    7: 0.51,
    8: 0.57,
    9: 0.63,
    10: 0.68,
    11: 0.73,
    12: 0.78,
    13: 0.83,
    14: 0.88,
    15: 0.93,
    16: 0.98,
    17: 1.02,
    18: 1.07,
    19: 1.11,
    20: 1.16,
    21: 1.21,
    22: 1.25,
    23: 1.30,
    24: 1.34,
  };

  /// Loans run for at most two years. Every month from 1 to
  /// [maxLoanTenureMonths] is selectable, and each has its own rate in
  /// [loanRatesByTenure].
  static const maxLoanTenureMonths = 24;

  /// Processing fee, also called the management fee: a flat
  /// [flatProcessingFee] on every loan from [minLoanAmount] up to and
  /// including [processingFeeThreshold]. The moment a loan goes past that —
  /// ₦500,001 counts — the fee becomes [loanProcessingFeeRate] of the **whole
  /// principal**, not of the excess over the threshold.
  ///
  /// The two rules meet exactly at the threshold — 1% of ₦500,000 is ₦5,000 —
  /// so the fee curve is continuous and never jumps. It is always deducted
  /// from the disbursement, never added to what is owed.
  static const flatProcessingFee = 5000.0;
  static const processingFeeThreshold = 500000.0;
  static const loanProcessingFeeRate = 0.01;

  // Security ---------------------------------------------------------------
  /// Code lengths are deliberately **not** tunable. Every passcode and PIN
  /// is stored as a hash of a code of this length; changing it would lock out
  /// every customer who already has one.
  static const signInPasscodeLength = 6;
  static const transactionPinLength = 4;

  static const maxPasscodeAttempts = 5;

  /// Idle minutes before the app demands the passcode again.
  static const lockTimeoutMinutes = 2;

  // Loan eligibility --------------------------------------------------------
  /// What a customer may be offered, before [maxLoanAmount] caps it:
  ///   [loanBaseCap]
  ///   + everything they have saved x [loanSavingsMultiple]
  ///   + every credit-score point above [loanScoreBaseline] x
  ///     [loanScorePerPoint]
  /// rounded down to the nearest [loanOfferRounding].
  static const loanBaseCap = 100000.0;
  static const loanSavingsMultiple = 1.5;
  static const loanScoreBaseline = 500;
  static const loanScorePerPoint = 400.0;
  static const loanOfferRounding = 5000.0;

  // Credit score ------------------------------------------------------------
  /// A score out of 850, built from what a customer has actually done.
  static const creditBaseScore = 560;
  static const creditPointsPerPlan = 18;
  static const creditPlanPointsCap = 90;
  static const creditNairaPerSavingsPoint = 25000.0;
  static const creditSavingsPointsCap = 100;
  static const creditPointsPerRepaidLoan = 30;
  static const creditRepaidPointsCap = 120;
  static const creditOverduePenalty = 90;
  static const creditVerifiedBonus = 40;
  static const creditScoreFloor = 300;
  static const creditScoreCeiling = 850;

  // Limits -----------------------------------------------------------------
  static const dailyTransferLimit = 1000000.0;
  // Collection account ------------------------------------------------------
  /// Where customers pay in — to fund a wallet, open savings or repay a loan.
  /// Money only reaches a wallet once an admin has matched the transfer
  /// against this account's statement.
  static const companyAccountName = 'Quadrilateral Technologies Ltd';
  static const companyAccountNumber = '1018548852';
  static const companyBank = 'Zenith Bank';

  static const supportEmail = 'support@kudi9ja.com';
  static const supportPhone = '+234 800 5834 952';

  // Legal entity -----------------------------------------------------------
  /// Kudi9ja is a product; the company behind it is the one that contracts
  /// with customers, and it is the name that must appear on every agreement.
  static const legalEntity = 'Quadrilateral Technologies Limited';
  static const rcNumber = 'RC 1657731';
  static const registeredAddress = 'Kudi9ja Limited, Lagos, Nigeria';

  /// Inboxes, split by the document each one answers for.
  static const legalEmail = 'legal@kudi9ja.com';
  static const privacyEmail = 'privacy@kudi9ja.com';

  /// WhatsApp lines the support team answers on.
  static const supportWhatsapp = <String, String>{
    '+234 805 679 1426': 'https://wa.me/2348056791426',
    '+234 803 630 0582': 'https://wa.me/2348036300582',
  };
}

/// A curated lock-period preset surfaced in the savings flow.
class LockPreset {
  const LockPreset(this.months, this.label, this.note);
  final int months;
  final String label;
  final String note;
}

const kLockPresets = <LockPreset>[
  LockPreset(1, '1 month', 'Short & flexible'),
  LockPreset(3, '3 months', 'Quarterly goal'),
  LockPreset(6, '6 months', 'Half-year builder'),
  LockPreset(12, '1 year', 'Most popular'),
  LockPreset(24, '2 years', 'Serious growth'),
  LockPreset(36, '3 years', 'Long horizon'),
  LockPreset(60, '5 years', 'Maximum yield'),
];
