/// Product rules for Kudi9ja. Single source of truth for every calculation.
abstract final class AppConfig {
  static const appName = 'Kudi9ja';
  static const tagline = 'Pay smart. Pay global.';

  /// The one email address that is granted owner when it opens an account.
  ///
  /// **Empty in any real build**, and deliberately so. Panel access is a grant
  /// the server makes, and the first person to sign up on a server is a
  /// stranger — so nobody becomes an admin by being early. It exists at all
  /// because a brand-new deployment needs a first owner, and that owner is
  /// named in deployment configuration rather than discovered.
  ///
  /// Mirrors `AdminBootstrapService` on the server, which reads
  /// `kudi9ja.bootstrap.owner-email`.
  static String bootstrapOwnerEmail = '';

  // API --------------------------------------------------------------------
  /// Where the server is.
  ///
  /// Overridable at build time so a debug build can point at a laptop without
  /// editing source and risking that edit being committed:
  ///
  /// ```
  /// flutter run --dart-define=KUDI9JA_API=http://10.0.2.2:8080/api/v1
  /// ```
  ///
  /// (`10.0.2.2` is the host machine as seen from the Android emulator;
  /// `localhost` there is the emulator itself.)
  static const apiBaseUrl = String.fromEnvironment(
    'KUDI9JA_API',
    defaultValue: 'https://kudi9ja-mobile-backend.onrender.com/api/v1',
  );

  /// How the server labels this session in the customer's device list, so a
  /// stolen session can be recognised and signed out from the security screen.
  static const deviceLabel = 'Kudi9ja mobile';

  // Savings ----------------------------------------------------------------
  /// Annual return on locked savings, paid to the wallet the moment the
  /// plan is created.
  static const savingsAnnualRate = 0.17;

  /// The year the annual rate is spread over. A lock of any length earns
  /// [savingsAnnualRate] x days / [daysPerYear], so 365 days pays the full
  /// 17% and 171 days pays 7.96%.
  static const daysPerYear = 365;

  /// Fixed Savings locks in **days**, from 30 days to five years. A customer
  /// who wants 171 days gets 171 days, priced exactly.
  static const minLockDays = 30;
  static const maxLockDays = 1825; // 5 years
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

  // Pay-in, payout and thrift ----------------------------------------------
  /// The smallest pay-in we will match against the bank statement, and the
  /// smallest payout worth a bank transfer.
  static const minDepositAmount = 100.0;
  static const minWithdrawalAmount = 500.0;

  /// Thrift circles: what a round must be worth, and how many people a
  /// circle can carry before it stops being a group anyone can keep track of.
  static const minCircleContribution = 1000.0;
  static const minCircleMembers = 2;
  static const maxCircleMembers = 12;

  /// Seconds before a one-time code can be sent again.
  static const otpResendSeconds = 45;

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

/// A curated lock-period preset surfaced in the savings flow. Presets are a
/// shortcut, not a constraint — any number of days between the platform
/// minimum and maximum can be typed in.
class LockPreset {
  const LockPreset(this.days, this.label, this.note);
  final int days;
  final String label;
  final String note;
}

const kLockPresets = <LockPreset>[
  LockPreset(30, '30 days', 'Short & flexible'),
  LockPreset(90, '90 days', 'Quarterly goal'),
  LockPreset(180, '180 days', 'Half-year builder'),
  LockPreset(365, '1 year', 'Most popular'),
  LockPreset(730, '2 years', 'Serious growth'),
  LockPreset(1095, '3 years', 'Long horizon'),
  LockPreset(1825, '5 years', 'Maximum yield'),
];
