/// The one shape every refused request comes back in.
///
/// The server answers every failure with the same envelope — a machine-readable
/// [code], a [message] written for the customer, and [details] carrying whatever
/// the code needs to be acted on. That is worth honouring rather than flattening
/// into a string: the message is what a person reads, and the code is what the
/// app decides with. Matching on message text would break the first time the
/// wording is improved.
library;

/// Every reason the server refuses a request.
///
/// Mirrors `ErrorCode` on the server. A value the app has never heard of maps to
/// [unknown] rather than throwing — a server that grows a new code must not
/// crash an app that has not been updated yet.
enum ApiErrorCode {
  // Shape and plumbing
  validationFailed('VALIDATION_FAILED'),
  notFound('NOT_FOUND'),
  conflict('CONFLICT'),
  internal('INTERNAL'),
  rateLimited('RATE_LIMITED'),
  maintenance('MAINTENANCE'),
  featureDisabled('FEATURE_DISABLED'),
  idempotencyConflict('IDEMPOTENCY_CONFLICT'),

  // Session
  unauthenticated('UNAUTHENTICATED'),
  badCredentials('BAD_CREDENTIALS'),
  tokenExpired('TOKEN_EXPIRED'),
  tokenInvalid('TOKEN_INVALID'),

  // Account standing
  accountLocked('ACCOUNT_LOCKED'),
  accountFrozen('ACCOUNT_FROZEN'),
  accountDormant('ACCOUNT_DORMANT'),
  accountClosed('ACCOUNT_CLOSED'),

  // Sign-up
  emailTaken('EMAIL_TAKEN'),
  phoneTaken('PHONE_TAKEN'),
  bvnTaken('BVN_TAKEN'),
  ninTaken('NIN_TAKEN'),
  underage('UNDERAGE'),

  // Codes and secrets
  otpInvalid('OTP_INVALID'),
  otpExpired('OTP_EXPIRED'),
  otpCooldown('OTP_COOLDOWN'),
  pinInvalid('PIN_INVALID'),
  passcodeInvalid('PASSCODE_INVALID'),
  pinRequired('PIN_REQUIRED'),
  weakPassword('WEAK_PASSWORD'),

  // Identity
  kycFailed('KYC_FAILED'),
  kycTierTooLow('KYC_TIER_TOO_LOW'),
  nameMismatch('NAME_MISMATCH'),
  legalAcceptanceRequired('LEGAL_ACCEPTANCE_REQUIRED'),

  // Permission
  forbidden('FORBIDDEN'),
  notAnAdmin('NOT_AN_ADMIN'),
  selfLockout('SELF_LOCKOUT'),
  lastOwner('LAST_OWNER'),

  // Money
  insufficientFunds('INSUFFICIENT_FUNDS'),
  amountTooSmall('AMOUNT_TOO_SMALL'),
  amountTooLarge('AMOUNT_TOO_LARGE'),
  dailyLimitExceeded('DAILY_LIMIT_EXCEEDED'),
  receiptRequired('RECEIPT_REQUIRED'),
  noPayoutAccount('NO_PAYOUT_ACCOUNT'),
  alreadyReviewed('ALREADY_REVIEWED'),

  // Savings
  planNotMatured('PLAN_NOT_MATURED'),
  planCannotBreak('PLAN_CANNOT_BREAK'),
  planClosed('PLAN_CLOSED'),
  lockTooShort('LOCK_TOO_SHORT'),
  lockTooLong('LOCK_TOO_LONG'),
  termTooShort('TERM_TOO_SHORT'),

  // Lending
  notEligible('NOT_ELIGIBLE'),
  offerExceeded('OFFER_EXCEEDED'),
  tenureUnpriced('TENURE_UNPRICED'),
  loanClosed('LOAN_CLOSED'),
  cancellationWindowClosed('CANCELLATION_WINDOW_CLOSED'),

  // Thrift
  memberNotACustomer('MEMBER_NOT_A_CUSTOMER'),
  circleFull('CIRCLE_FULL'),
  circleComplete('CIRCLE_COMPLETE'),
  alreadyAMember('ALREADY_A_MEMBER'),
  alreadyContributed('ALREADY_CONTRIBUTED'),
  notAMember('NOT_A_MEMBER'),

  // Settings
  settingsInvalid('SETTINGS_INVALID'),
  settingsStale('SETTINGS_STALE'),

  /// The server said something this build does not know about.
  unknown('UNKNOWN'),

  /// No answer at all — the phone is offline, or the request timed out. Not a
  /// server code; the app raises it so callers have one thing to catch.
  network('NETWORK');

  const ApiErrorCode(this.wire);

  /// The value as the server writes it.
  final String wire;

  static ApiErrorCode parse(String? value) {
    if (value == null) return unknown;
    for (final code in values) {
      if (code.wire == value) return code;
    }
    return unknown;
  }
}

/// Why a request never came back.
///
/// All four are the same thing to the code that catches them — no reply — and
/// all four used to produce one sentence about the customer's connection. That
/// sentence is a diagnosis, and three times out of four it is the wrong one: it
/// sends whoever reads it to the server logs, where a request that never
/// arrived has left nothing to find.
///
/// So the wording differs per cause. A screenshot then says which happened,
/// which is the only evidence there is when the request never reached us.
enum NetworkFailure {
  /// A connection was made and the server did not answer in time.
  timeout,

  /// No connection could be opened at all. This is the one that really is the
  /// customer's signal.
  unreachable,

  /// A connection was opened and died before the reply was complete. Usually a
  /// socket the phone had kept alive that the other end had already closed —
  /// nothing to do with signal, and it clears on a second attempt.
  dropped,

  /// Something answered, but it was not the application: a proxy's own page
  /// while the instance behind it starts.
  notTheApp,
}

/// A request the server refused, or one that never arrived.
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.details = const {},
    this.status,
    this.path,
  });

  /// The request never came back.
  ///
  /// Worded for a customer standing in a shop with one bar of signal, not for a
  /// developer reading a log — but worded *differently* per [NetworkFailure],
  /// because the customer's next move differs too, and because the sentence on
  /// screen is the only record of a request that never reached the server.
  factory ApiException.offline(NetworkFailure why, [String? detail]) =>
      ApiException(
        code: ApiErrorCode.network,
        message: switch (why) {
          NetworkFailure.timeout =>
            'Kudi9ja took too long to answer. Nothing was sent — try again.',
          NetworkFailure.unreachable =>
            'We could not reach Kudi9ja. Check your connection and try again.',
          NetworkFailure.dropped =>
            'The connection dropped before Kudi9ja finished. Try again.',
          NetworkFailure.notTheApp =>
            'Kudi9ja is starting up. Give it a moment and try again.',
        },
        details: {'why': why.name, if (detail != null) 'detail': detail},
      );

  /// Reads the server's error envelope.
  factory ApiException.fromBody(
    Map<String, dynamic> body, {
    int? status,
  }) {
    final rawMessage = body['message'];
    return ApiException(
      code: ApiErrorCode.parse(body['code'] as String?),
      // A body without a message is a server bug, but showing the customer a
      // blank dialog is worse than showing them something.
      message: rawMessage is String && rawMessage.trim().isNotEmpty
          ? rawMessage
          : 'Something went wrong. Please try again.',
      details: (body['details'] as Map?)?.cast<String, dynamic>() ?? const {},
      status: status,
      path: body['path'] as String?,
    );
  }

  final ApiErrorCode code;

  /// Safe to put in front of a customer. The server writes these deliberately.
  final String message;

  /// Field errors, limits, remaining attempts — whatever [code] needs.
  final Map<String, dynamic> details;

  final int? status;
  final String? path;

  /// Whether the session is gone and the customer has to sign in again.
  bool get isAuthFailure =>
      code == ApiErrorCode.unauthenticated ||
      code == ApiErrorCode.tokenExpired ||
      code == ApiErrorCode.tokenInvalid;

  /// Whether retrying the identical request could plausibly work.
  ///
  /// Money-moving calls carry an idempotency key, so a retry of one of those is
  /// safe: the server returns the original result rather than moving money
  /// twice.
  bool get isRetryable =>
      code == ApiErrorCode.network ||
      code == ApiErrorCode.internal ||
      code == ApiErrorCode.maintenance;

  /// Field-level messages from a validation failure, keyed by field name.
  Map<String, String> get fieldErrors {
    final fields = details['fields'];
    if (fields is Map) {
      return fields.map((k, v) => MapEntry('$k', '$v'));
    }
    return const {};
  }

  @override
  String toString() => 'ApiException(${code.wire}: $message)';
}
