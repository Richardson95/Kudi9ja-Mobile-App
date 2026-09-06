import 'package:uuid/uuid.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../models/app_notification.dart';
import '../models/deposit.dart';
import '../models/models.dart';
import '../models/thrift.dart';
import '../models/withdrawal.dart';
import 'api_client.dart';
import 'mappers.dart';

/// Every operation the app performs on the server, named the way the app talks
/// about them.
///
/// A thin layer on purpose. It knows paths, request shapes and which calls move
/// money; it holds no state and makes no decisions. `AppState` above it decides
/// what to do with an answer, and [ApiClient] below it deals with tokens and
/// transport — so the interesting logic stays in one place at each level rather
/// than smeared across all three.
///
/// **Idempotency.** Every call that moves money carries a freshly minted key.
/// The customer taps *Withdraw*, the request is sent, the phone loses signal
/// before the answer arrives, and they tap again. Without a key the server sees
/// two withdrawals; with one it recognises the second as the same request and
/// returns the original result. This matters most in exactly the conditions
/// where it is hardest to test — a bad connection — so the key is minted here,
/// once per logical operation, rather than left to call sites to remember.
class Kudi9jaApi {
  Kudi9jaApi(this._client);

  final ApiClient _client;
  static const _uuid = Uuid();

  /// A fresh idempotency key for one money-moving operation.
  static String newKey() => _uuid.v4();

  ApiClient get client => _client;

  // ═══════════════════════════════════════════════════════════════════════════
  // Sign-up
  //
  // Nine steps on the server, each validated as it is submitted rather than all
  // at the end. The draft holds the answers so far and its own token, so an
  // abandoned sign-up leaves a draft that expires rather than a half-made
  // account that can never be finished or signed into.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Opens a draft. Returns `draftId` and `signupToken`.
  Future<Map<String, dynamic>> startSignup({
    required String fullName,
    required String email,
    required String phone,
    required DateTime dateOfBirth,
    required String gender,
  }) async =>
      _asMap(await _client.post('/auth/signup/personal',
          authenticated: false,
          body: {
            'fullName': fullName,
            'email': email,
            'phone': phone,
            'dateOfBirth': _isoDate(dateOfBirth),
            'gender': gender,
          }));

  /// Sends the email verification code for a draft.
  Future<Map<String, dynamic>> sendSignupEmail(String draftId) async =>
      _asMap(await _client.post('/auth/signup/$draftId/email/resend',
          authenticated: false));

  Future<Map<String, dynamic>> verifySignupEmail(
          String draftId, String code) async =>
      _asMap(await _client.post('/auth/signup/$draftId/email',
          authenticated: false, body: {'code': code}));

  Future<Map<String, dynamic>> submitIdentity(
    String draftId, {
    required String bvn,
    required String nin,
    required String address,
    required String state,
  }) async =>
      _asMap(await _client.post('/auth/signup/$draftId/identity',
          authenticated: false,
          body: {'bvn': bvn, 'nin': nin, 'address': address, 'state': state}));

  Future<Map<String, dynamic>> submitPayout(
    String draftId, {
    required String bank,
    required String accountNumber,
  }) async =>
      _asMap(await _client.post('/auth/signup/$draftId/payout',
          authenticated: false,
          body: {'bank': bank, 'accountNumber': accountNumber}));

  Future<Map<String, dynamic>> submitPassword(
    String draftId, {
    required String password,
    required String securityQuestion,
    required String securityAnswer,
  }) async =>
      _asMap(await _client.post('/auth/signup/$draftId/password',
          authenticated: false,
          body: {
            'password': password,
            'securityQuestion': securityQuestion,
            'securityAnswer': securityAnswer,
          }));

  Future<Map<String, dynamic>> submitPasscode(
    String draftId, {
    required String passcode,
    required String confirmPasscode,
  }) async =>
      _asMap(await _client.post('/auth/signup/$draftId/passcode',
          authenticated: false,
          body: {'passcode': passcode, 'confirmPasscode': confirmPasscode}));

  Future<Map<String, dynamic>> submitPin(
    String draftId, {
    required String pin,
    required String confirmPin,
  }) async =>
      _asMap(await _client.post('/auth/signup/$draftId/pin',
          authenticated: false, body: {'pin': pin, 'confirmPin': confirmPin}));

  /// Records which versions of the agreements were accepted.
  ///
  /// The versions matter as much as the acceptance: the Lending Agreement a
  /// customer agreed to is the one that governs their loans, and "they accepted
  /// something, once" is not a record anyone can act on later.
  Future<Map<String, dynamic>> acceptAgreements(
    String draftId, {
    required Map<String, String> acceptedVersions,
    bool accepted = true,
  }) async =>
      _asMap(await _client.post('/auth/signup/$draftId',
          authenticated: false,
          body: {'acceptedVersions': acceptedVersions, 'accepted': accepted}));

  /// Turns a completed draft into an account, and signs the customer in.
  Future<Session> completeSignup(String draftId) async {
    final body = _asMap(await _client.post('/auth/signup/$draftId/complete',
        authenticated: false, body: {'device': AppConfig.deviceLabel}));
    return _storeSession(body);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Session
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Session> signIn({required String email, required String password}) async {
    final body = _asMap(await _client.post('/auth/signin',
        // A stale token on a sign-in request is how a half-expired session
        // produces a 401 that looks like a wrong password.
        authenticated: false,
        body: {
          'email': email,
          'password': password,
          'device': AppConfig.deviceLabel,
        }));
    return _storeSession(body);
  }

  /// Ends this session on the server, then locally.
  ///
  /// The local clear happens whatever the server says. A customer who taps sign
  /// out on a phone they are about to hand over must not still be signed in
  /// because the network was down.
  Future<void> signOut() async {
    try {
      await _client.post('/auth/signout');
    } catch (_) {
      // Deliberately swallowed; see above.
    }
    await _client.tokens.clear();
  }

  Future<void> signOutEverywhere() async {
    try {
      await _client.post('/auth/signout/all');
    } finally {
      await _client.tokens.clear();
    }
  }

  Future<List<Map<String, dynamic>>> sessions() async =>
      _asList(await _client.get('/auth/sessions'));

  Future<void> endSession(String sessionId) =>
      _client.delete('/auth/sessions/$sessionId');

  // ── Codes and secrets ──────────────────────────────────────────────────────

  /// Checks the sign-in passcode.
  ///
  /// Counted on the server, not on the device. A local counter is reset by
  /// reinstalling the app, which makes it no counter at all.
  Future<Map<String, dynamic>> verifyPasscode(String passcode) async =>
      _asMap(await _client.post('/auth/passcode/verify',
          body: {'passcode': passcode}));

  Future<Map<String, dynamic>> verifyPin(String pin) async =>
      _asMap(await _client.post('/auth/pin/verify', body: {'pin': pin}));

  Future<void> changePasscode({
    required String currentPasscode,
    required String newPasscode,
  }) =>
      _client.patch('/auth/passcode', body: {
        'currentPasscode': currentPasscode,
        'newPasscode': newPasscode,
      });

  Future<void> changePin({required String currentPin, required String newPin}) =>
      _client.patch('/auth/pin', body: {'currentPin': currentPin, 'newPin': newPin});

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _client.patch('/auth/password', body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  Future<void> forgotPassword(String email) => _client.post(
      '/auth/password/forgot',
      authenticated: false,
      body: {'email': email});

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _client.post('/auth/password/reset',
          authenticated: false,
          body: {'email': email, 'code': code, 'newPassword': newPassword});

  Future<Map<String, dynamic>> sendOtp({
    required String email,
    required String purpose,
  }) async =>
      _asMap(await _client.post('/auth/otp/send',
          authenticated: false, body: {'email': email, 'purpose': purpose}));

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String purpose,
    required String code,
  }) async =>
      _asMap(await _client.post('/auth/otp/verify',
          authenticated: false,
          body: {'email': email, 'purpose': purpose, 'code': code}));

  // ═══════════════════════════════════════════════════════════════════════════
  // The customer
  // ═══════════════════════════════════════════════════════════════════════════

  Future<AppUser> me() async => userFromApi(_asMap(await _client.get('/me')));

  /// Everything the dashboard needs, in one call.
  ///
  /// Six separate requests on a cold start would each wake the connection, each
  /// pay a round trip, and arrive at different moments — so the balance would
  /// settle before the savings total and the screen would visibly rearrange
  /// itself under the customer's thumb.
  Future<Map<String, dynamic>> dashboard() async =>
      _asMap(await _client.get('/me/dashboard'));

  Future<AppUser> updateProfile({
    String? phone,
    String? address,
    String? state,
    AppThemeMode? themeMode,
    bool? hideBalance,
    bool? biometricsEnabled,
    bool? autoDebit,
  }) async =>
      userFromApi(_asMap(await _client.patch('/me', body: {
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
        if (state != null) 'state': state,
        if (themeMode != null) 'themeMode': themeModeToApi(themeMode),
        if (hideBalance != null) 'hideBalance': hideBalance,
        if (biometricsEnabled != null) 'biometricsEnabled': biometricsEnabled,
        if (autoDebit != null) 'autoDebit': autoDebit,
      })));

  /// Asks for the code that authorises a change of payout account.
  ///
  /// Changing where money leaves to is the single most valuable thing an
  /// account takeover can do, which is why it takes a code sent out of band and
  /// the transaction PIN, and why it is not just another profile field.
  Future<Map<String, dynamic>> requestPayoutChangeCode() async =>
      _asMap(await _client.post('/me/payout/code'));

  Future<AppUser> changePayoutAccount({
    required String bank,
    required String accountNumber,
    required String code,
    required String pin,
  }) async =>
      userFromApi(_asMap(await _client.patch('/me/payout', body: {
        'bank': bank,
        'accountNumber': accountNumber,
        'code': code,
        'pin': pin,
      })));

  Future<Map<String, dynamic>> closureEligibility() async =>
      _asMap(await _client.get('/me/closure'));

  Future<Map<String, dynamic>> requestClosureCode() async =>
      _asMap(await _client.post('/me/closure/code'));

  Future<Map<String, dynamic>> closeAccount({
    required String code,
    required String password,
    String reason = '',
  }) async =>
      _asMap(await _client.delete('/account',
          body: {'code': code, 'password': password, 'reason': reason}));

  Future<Map<String, dynamic>> dataExport() async =>
      _asMap(await _client.get('/me/data-export'));

  Future<List<Map<String, dynamic>>> outstandingAgreements() async =>
      _asList(await _client.get('/me/legal/outstanding'));

  // ═══════════════════════════════════════════════════════════════════════════
  // Wallet and ledger
  // ═══════════════════════════════════════════════════════════════════════════

  Future<WalletSnapshot> wallet() async =>
      WalletSnapshot.fromApi(_asMap(await _client.get('/wallet')));

  Future<Page<Transaction>> transactions({
    int page = 0,
    int size = 50,
    String? filter,
  }) async =>
      Page.fromApi(
        await _client.get('/transactions',
            query: {'page': page, 'size': size, 'filter': filter}),
        transactionFromApi,
      );

  // ── Money in ───────────────────────────────────────────────────────────────

  /// The reference currently on the customer's screen.
  ///
  /// Idempotent: asking twice gives the same reference. A customer who opens
  /// the pay-in screen three times has not made three payments, and three
  /// references on their record would be three things for an admin to rule out.
  Future<PaymentInstruction> paymentReference() async =>
      PaymentInstruction.fromApi(_asMap(await _client.get('/payins/reference')));

  /// Records that the reference was copied, and returns the next one.
  ///
  /// The copy is the event worth recording — until then it is text on a screen;
  /// afterwards it is on its way into a bank narration, and an admin holding a
  /// statement needs to be able to find it.
  Future<PaymentInstruction> referenceCopied() async =>
      PaymentInstruction.fromApi(
          _asMap(await _client.post('/payins/reference/copied')));

  /// Claims a transfer already sent, with the receipt.
  ///
  /// Moves no money. The wallet is credited only when an admin has matched the
  /// claim against the bank statement.
  Future<DepositClaim> submitClaim({
    required double amount,
    required String reference,
    required String senderName,
    String? senderBank,
    DepositPurpose purpose = DepositPurpose.wallet,
    String? loanId,
    required List<int> receiptBytes,
    required String receiptFilename,
    String? receiptContentType,
  }) async =>
      claimFromApi(_asMap(await _client.upload(
        '/payins',
        fieldName: 'receipt',
        bytes: receiptBytes,
        filename: receiptFilename,
        contentType: receiptContentType,
        idempotencyKey: newKey(),
        fields: {
          'amount': '$amount',
          'reference': reference,
          'senderName': senderName,
          if (senderBank != null) 'senderBank': senderBank,
          'purpose': purpose == DepositPurpose.loanRepayment
              ? 'LOAN_REPAYMENT'
              : 'WALLET',
          if (loanId != null) 'loanId': loanId,
        },
      )));

  Future<Page<DepositClaim>> claims({int page = 0, int size = 25}) async =>
      Page.fromApi(
        await _client.get('/payins', query: {'page': page, 'size': size}),
        (j) => claimFromApi(j),
      );

  // ── Money out ──────────────────────────────────────────────────────────────

  /// Requests a withdrawal. Debits the wallet immediately and queues the
  /// transfer for an admin to make from the collection account.
  ///
  /// The destination is not the customer's to choose here — it is the account
  /// they named at sign-up, and the server refuses anything else. It is sent
  /// so the server can refuse a mismatch loudly rather than silently paying
  /// somewhere the customer did not expect.
  Future<WithdrawalRequest> requestWithdrawal({
    required double amount,
    required String pin,
    required String bank,
    required String accountNumber,
  }) async =>
      withdrawalFromApi(_asMap(await _client.post(
        '/withdrawals',
        idempotencyKey: newKey(),
        body: {
          'amount': amount,
          'pin': pin,
          'bank': bank,
          'accountNumber': accountNumber,
        },
      )));

  Future<Page<WithdrawalRequest>> withdrawals({int page = 0, int size = 25}) async =>
      Page.fromApi(
        await _client.get('/withdrawals', query: {'page': page, 'size': size}),
        (j) => withdrawalFromApi(j),
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // Savings
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<SavingsPlan>> plans() async =>
      plansFromApi(await _client.get('/savings/plans'));

  Future<SavingsPlan> plan(String id) async =>
      planFromApi(_asMap(await _client.get('/savings/plans/$id')));

  /// What a fixed plan would pay, before committing to it.
  ///
  /// Quoted by the server rather than worked out on the phone, so the figure a
  /// customer is shown is the figure they will be given. An app that prices
  /// locally will one day quote a rate the server no longer honours.
  Future<Map<String, dynamic>> quoteFixed({
    required double amount,
    required int days,
  }) async =>
      _asMap(await _client.get('/savings/quote/fixed',
          query: {'amount': amount, 'days': days}));

  Future<Map<String, dynamic>> quoteTarget({
    required double goal,
    required int months,
    required String frequency,
  }) async =>
      _asMap(await _client.get('/savings/quote/target',
          query: {'goal': goal, 'months': months, 'frequency': frequency}));

  Future<SavingsPlan> createFixedPlan({
    required String title,
    required double principal,
    required int days,
    required String emoji,
    required String pin,
  }) async =>
      planFromApi(_asMap(await _client.post(
        '/savings/plans/fixed',
        idempotencyKey: newKey(),
        body: {
          'title': title,
          'principal': principal,
          'days': days,
          'emoji': emoji,
          'pin': pin,
        },
      )));

  Future<SavingsPlan> createTargetPlan({
    required String title,
    required double goal,
    required String frequency,
    required int months,
    required String emoji,
    required String pin,
  }) async =>
      planFromApi(_asMap(await _client.post(
        '/savings/plans/target',
        idempotencyKey: newKey(),
        body: {
          'title': title,
          'goal': goal,
          'frequency': frequency,
          'months': months,
          'emoji': emoji,
          'pin': pin,
        },
      )));

  Future<SavingsPlan> topUpPlan(String id,
          {required double amount, required String pin}) async =>
      planFromApi(_asMap(await _client.post(
        '/savings/plans/$id/topup',
        idempotencyKey: newKey(),
        body: {'amount': amount, 'pin': pin},
      )));

  Future<Map<String, dynamic>> withdrawPlan(String id, {required String pin}) async =>
      _asMap(await _client.post(
        '/savings/plans/$id/withdraw',
        idempotencyKey: newKey(),
        body: {'pin': pin},
      ));

  /// Breaks a target plan early, forfeiting the bonus. Fixed plans cannot be
  /// broken at all — the server refuses, and the app should not offer it.
  Future<Map<String, dynamic>> breakPlan(String id, {required String pin}) async =>
      _asMap(await _client.post(
        '/savings/plans/$id/break',
        idempotencyKey: newKey(),
        body: {'pin': pin},
      ));

  Future<SavingsPlan> setAutoSave(
    String id, {
    required bool enabled,
    double? amount,
    String? frequency,
  }) async =>
      planFromApi(_asMap(await _client.patch('/savings/plans/$id/autosave', body: {
        'enabled': enabled,
        if (amount != null) 'amount': amount,
        if (frequency != null) 'frequency': frequency,
      })));

  // ═══════════════════════════════════════════════════════════════════════════
  // Lending
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Loan>> loans() async => loansFromApi(await _client.get('/loans'));

  Future<Loan> loan(String id) async =>
      loanFromApi(_asMap(await _client.get('/loans/$id')));

  Future<LoanEligibility> eligibility() async =>
      LoanEligibility.fromApi(_asMap(await _client.get('/loans/eligibility')));

  /// The full cost of a loan before requesting it: fee, net, interest, total
  /// and the repayment schedule. The server's arithmetic, so the total the
  /// customer agrees to is the total they will be charged.
  Future<Map<String, dynamic>> quoteLoan({
    required double amount,
    required int months,
  }) async =>
      _asMap(await _client.get('/loans/quote',
          query: {'amount': amount, 'months': months}));

  Future<Loan> requestLoan({
    required double amount,
    required int months,
    required String purpose,
    required String pin,
  }) async =>
      loanFromApi(_asMap(await _client.post(
        '/loans',
        idempotencyKey: newKey(),
        body: {'amount': amount, 'months': months, 'purpose': purpose, 'pin': pin},
      )));

  Future<Map<String, dynamic>> repayLoan(String id,
          {required double amount, required String pin}) async =>
      _asMap(await _client.post(
        '/loans/$id/repay',
        idempotencyKey: newKey(),
        body: {'amount': amount, 'pin': pin},
      ));

  /// Settles a loan early. Half the interest on the months it never ran is
  /// given back.
  Future<Map<String, dynamic>> settleLoan(String id, {required String pin}) async =>
      _asMap(await _client.post(
        '/loans/$id/settle',
        idempotencyKey: newKey(),
        body: {'pin': pin},
      ));

  Future<Map<String, dynamic>> cancelLoan(String id, {required String pin}) async =>
      _asMap(await _client.post(
        '/loans/$id/cancel',
        idempotencyKey: newKey(),
        body: {'pin': pin},
      ));

  Future<CreditScoreSnapshot> creditScore() async =>
      CreditScoreSnapshot.fromApi(_asMap(await _client.get('/credit-score')));

  // ═══════════════════════════════════════════════════════════════════════════
  // Thrift circles
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<ThriftCircle>> circles() async =>
      circlesFromApi(await _client.get('/circles'));

  Future<ThriftCircle> circle(String id) async =>
      circleFromApi(_asMap(await _client.get('/circles/$id')));

  /// Creates a circle.
  ///
  /// Members are named by customer reference, and every one must be a real
  /// Kudi9ja account — a circle built around people who do not exist collects
  /// nothing from them and pays the pot out anyway.
  Future<ThriftCircle> createCircle({
    required String name,
    required double contribution,
    required String frequency,
    required List<String> memberRefs,
    required String emoji,
    required String pin,
  }) async =>
      circleFromApi(_asMap(await _client.post(
        '/circles',
        idempotencyKey: newKey(),
        body: {
          'name': name,
          'contribution': contribution,
          'frequency': frequency,
          'memberRefs': memberRefs,
          'emoji': emoji,
          'pin': pin,
        },
      )));

  Future<ThriftCircle> joinCircle(String inviteCode) async =>
      circleFromApi(_asMap(await _client.post('/circles/join',
          body: {'inviteCode': inviteCode})));

  Future<Map<String, dynamic>> contributeToCircle(String id,
          {required String pin}) async =>
      _asMap(await _client.post(
        '/circles/$id/contribute',
        idempotencyKey: newKey(),
        body: {'pin': pin},
      ));

  Future<Map<String, dynamic>> collectCirclePot(String id,
          {required String pin}) async =>
      _asMap(await _client.post(
        '/circles/$id/payout',
        idempotencyKey: newKey(),
        body: {'pin': pin},
      ));

  Future<void> leaveCircle(String id) => _client.post('/circles/$id/leave');

  // ═══════════════════════════════════════════════════════════════════════════
  // Notifications
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Page<AppNotification>> notifications({int page = 0, int size = 50}) async =>
      Page.fromApi(
        await _client.get('/notifications', query: {'page': page, 'size': size}),
        notificationFromApi,
      );

  Future<int> unreadCount() async {
    final body = await _client.get('/notifications/unread-count');
    if (body is num) return body.toInt();
    final map = _asMap(body);
    return (map['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markNotificationsRead() => _client.post('/notifications/read');

  Future<void> clearNotifications() => _client.delete('/notifications');

  Future<Map<String, dynamic>> notificationPreferences() async =>
      _asMap(await _client.get('/notifications/preferences'));

  Future<Map<String, dynamic>> setNotificationPreferences(
          Map<String, dynamic> preferences) async =>
      _asMap(await _client.patch('/notifications/preferences', body: preferences));

  /// Registers this handset for push.
  ///
  /// Registered against the *account*, not the device, so a customer who signs
  /// in on a second phone gets notifications on both — and signing out removes
  /// only the phone signed out of.
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceLabel,
  }) =>
      _client.post('/notifications/devices', body: {
        'token': token,
        'platform': platform,
        'deviceLabel': deviceLabel ?? AppConfig.deviceLabel,
      });

  Future<void> unregisterDevice(String token) =>
      _client.delete('/notifications/devices/$token');

  // ═══════════════════════════════════════════════════════════════════════════
  // Reference data
  // ═══════════════════════════════════════════════════════════════════════════

  /// The rates and limits the app displays.
  ///
  /// Worth fetching rather than reading from `AppConfig`: an admin can change
  /// any of them from the panel, and an app quoting a rate the server no longer
  /// honours is quoting a price it cannot deliver.
  Future<Map<String, dynamic>> publicSettings() async =>
      _asMap(await _client.get('/settings/public'));

  Future<List<Map<String, dynamic>>> banks() async =>
      _asList(await _client.get('/banks'));

  Future<List<String>> states() async {
    final body = await _client.get('/states');
    return body is List ? body.map((e) => '$e').toList() : const [];
  }

  Future<Map<String, dynamic>> legalDocument(String kind) async =>
      _asMap(await _client.get('/legal/$kind'));

  Future<List<Map<String, dynamic>>> legalDocuments() async =>
      _asList(await _client.get('/legal'));

  // ═══════════════════════════════════════════════════════════════════════════
  // Plumbing
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Session> _storeSession(Map<String, dynamic> body) async {
    await _client.tokens.save(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      expiresInSeconds: (body['expiresInSeconds'] as num?)?.toInt() ?? 900,
      sessionId: body['sessionId'] as String?,
    );
    return Session(
      user: userFromApi(_obj(body['profile'])),
      isAdmin: body['admin'] as bool? ?? false,
      sessionId: body['sessionId'] as String? ?? '',
    );
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _asMap(Object? value) => _obj(value);

  static List<Map<String, dynamic>> _asList(Object? value) => value is List
      ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const [];

  static Map<String, dynamic> _obj(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
}

/// What a successful sign-in or sign-up hands back.
class Session {
  const Session({
    required this.user,
    required this.isAdmin,
    required this.sessionId,
  });

  final AppUser user;

  /// Whether this account currently holds panel access.
  ///
  /// The server's answer, checked on every admin request anyway. The app uses
  /// it only to decide whether to show the way in — it is not what grants
  /// anything.
  final bool isAdmin;

  final String sessionId;
}
