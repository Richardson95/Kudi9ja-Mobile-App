import '../models/admin.dart';
import '../models/deposit.dart';
import '../models/models.dart';
import '../models/withdrawal.dart';
import 'api_client.dart';
import 'kudi9ja_api.dart';
import 'mappers.dart';

/// The admin panel's half of the API.
///
/// Kept apart from [Kudi9jaApi] because it is a different job with a different
/// audience: these endpoints act on other people's money and are authorised by
/// role rather than merely by having signed in. Mixing them into the customer
/// surface would make it easy to call one by accident from a customer screen
/// and get a confusing refusal instead of a compile error.
///
/// Every method here can be refused with `NOT_AN_ADMIN` or `FORBIDDEN` even for
/// a signed-in admin, because permissions are per-action: approving a payment
/// and editing the rate card are different grants. The server decides; the
/// panel only asks.
class AdminApi {
  AdminApi(this._client);

  final ApiClient _client;

  // ═══════════════════════════════════════════════════════════════════════════
  // The board
  // ═══════════════════════════════════════════════════════════════════════════

  /// Funds held, queue depths, book size and headcount, in one call.
  Future<Map<String, dynamic>> overview() async =>
      _obj(await _client.get('/admin/overview'));

  Future<Map<String, dynamic>> whoAmI() async =>
      _obj(await _client.get('/admin/team/me'));

  // ═══════════════════════════════════════════════════════════════════════════
  // Customers
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Page<CustomerRecord>> customers({
    int page = 0,
    int size = 50,
    String? query,
  }) async =>
      Page.fromApi(
        await _client.get('/admin/customers',
            query: {'page': page, 'size': size, 'q': query}),
        customerRowFromApi,
      );

  Future<Map<String, dynamic>> customer(String id) async =>
      _obj(await _client.get('/admin/customers/$id'));

  Future<Page<Transaction>> customerTransactions(String id,
          {int page = 0, int size = 100}) async =>
      Page.fromApi(
        await _client.get('/admin/customers/$id/transactions',
            query: {'page': page, 'size': size}),
        transactionFromApi,
      );

  Future<Page<DepositClaim>> customerPayIns(String id) async => Page.fromApi(
        await _client.get('/admin/customers/$id/payins'),
        adminClaimFromApi,
      );

  Future<Page<WithdrawalRequest>> customerWithdrawals(String id) async =>
      Page.fromApi(
        await _client.get('/admin/customers/$id/withdrawals'),
        adminWithdrawalFromApi,
      );

  Future<List<SavingsPlan>> customerPlans(String id) async =>
      plansFromApi(await _client.get('/admin/customers/$id/plans'));

  Future<List<Loan>> customerLoans(String id) async =>
      loansFromApi(await _client.get('/admin/customers/$id/loans'));

  /// The payment references this customer has copied.
  ///
  /// What an admin compares against the narration on a bank statement. It is
  /// the whole reason references are recorded when they are copied rather than
  /// when they are shown.
  Future<List<Map<String, dynamic>>> customerReferences(String id) async =>
      _list(await _client.get('/admin/customers/$id/references'));

  Future<void> setCustomerStatus(String id,
          {required String status, String? note}) =>
      _client.post('/admin/customers/$id/status',
          body: {'status': status, if (note != null) 'note': note});

  Future<void> flagCustomer(String id, {required String reason}) =>
      _client.post('/admin/customers/$id/flag', body: {'reason': reason});

  // ═══════════════════════════════════════════════════════════════════════════
  // Money in
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Page<DepositClaim>> payIns({
    int page = 0,
    int size = 50,
    String? status,
  }) async =>
      Page.fromApi(
        await _client.get('/admin/payins',
            query: {'page': page, 'size': size, 'status': status}),
        adminClaimFromApi,
      );

  Future<DepositClaim> payIn(String claimId) async =>
      adminClaimFromApi(_obj(await _client.get('/admin/payins/$claimId')));

  /// A signed, expiring link to the receipt.
  ///
  /// Minted per view rather than stored, and every view is written to the audit
  /// log — a receipt carries a customer's name and bank details, and the
  /// Privacy Policy commits to being able to say who looked at one.
  Future<String?> receiptUrl(String claimId) async {
    final body = _obj(await _client.post('/admin/payins/$claimId/receipt'));
    return body['url'] as String? ?? body['receiptUrl'] as String?;
  }

  /// Credits the customer's wallet. This is the moment money becomes theirs.
  Future<DepositClaim> confirmPayIn(String claimId, {String? note}) async =>
      adminClaimFromApi(_obj(await _client.post(
        '/admin/payins/$claimId/confirm',
        idempotencyKey: Kudi9jaApi.newKey(),
        body: {if (note != null) 'note': note},
      )));

  /// Refuses a claim. The reason is required — it is what the customer is told,
  /// and "rejected" on its own leaves them with nothing to act on.
  Future<DepositClaim> rejectPayIn(String claimId, {required String note}) async =>
      adminClaimFromApi(_obj(await _client.post(
        '/admin/payins/$claimId/reject',
        body: {'note': note},
      )));

  /// Credits that arrived with no usable narration, waiting to be traced.
  Future<Page<Map<String, dynamic>>> unmatched({int page = 0, int size = 50}) async =>
      Page.fromApi(
        await _client.get('/admin/payins/unmatched',
            query: {'page': page, 'size': size}),
        (j) => j,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // Money out
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Page<WithdrawalRequest>> withdrawals({
    int page = 0,
    int size = 50,
    String? status,
  }) async =>
      Page.fromApi(
        await _client.get('/admin/withdrawals',
            query: {'page': page, 'size': size, 'status': status}),
        adminWithdrawalFromApi,
      );

  /// Marks a withdrawal as paid.
  ///
  /// The transfer itself is made by hand from the collection account; this
  /// records that it was. [payoutReference] is the bank's own reference for
  /// that transfer, which is what ties the two together if it is ever queried.
  Future<WithdrawalRequest> approveWithdrawal(
    String id, {
    String? payoutReference,
    String? note,
  }) async =>
      adminWithdrawalFromApi(_obj(await _client.post(
        '/admin/withdrawals/$id/approve',
        idempotencyKey: Kudi9jaApi.newKey(),
        body: {
          if (payoutReference != null) 'payoutReference': payoutReference,
          if (note != null) 'note': note,
        },
      )));

  /// Declines a withdrawal and returns the money to the wallet.
  Future<WithdrawalRequest> declineWithdrawal(String id,
          {required String reason}) async =>
      adminWithdrawalFromApi(_obj(await _client.post(
        '/admin/withdrawals/$id/decline',
        idempotencyKey: Kudi9jaApi.newKey(),
        body: {'reason': reason},
      )));

  // ═══════════════════════════════════════════════════════════════════════════
  // The book
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Page<Map<String, dynamic>>> loans({
    int page = 0,
    int size = 50,
    String? status,
  }) async =>
      Page.fromApi(
        await _client.get('/admin/loans',
            query: {'page': page, 'size': size, 'status': status}),
        (j) => j,
      );

  Future<void> remindBorrower(String loanId, {String? note}) =>
      _client.post('/admin/loans/$loanId/remind',
          body: {if (note != null) 'note': note});

  /// Writes a loan off. The reason is required and permanent — it is the record
  /// of why the business stopped expecting this money.
  Future<void> writeOffLoan(String loanId, {required String note}) =>
      _client.post('/admin/loans/$loanId/writeoff', body: {'note': note});

  // ═══════════════════════════════════════════════════════════════════════════
  // The team
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<AdminUser>> team() async {
    final body = await _client.get('/admin/team');
    final rows = body is List ? _list(body) : _list(_obj(body)['content']);
    return rows.map(teamMemberFromApi).toList();
  }

  Future<List<Map<String, dynamic>>> roles() async =>
      _list(await _client.get('/admin/team/roles'));

  Future<AdminUser> grantAccess({
    required String email,
    required String role,
  }) async =>
      teamMemberFromApi(_obj(await _client.post('/admin/team',
          body: {'email': email, 'role': role})));

  Future<AdminUser> changeRole(String adminId, String role) async =>
      teamMemberFromApi(_obj(
          await _client.patch('/admin/team/$adminId/role', body: {'role': role})));

  Future<AdminUser> setActive(String adminId, bool active, {String? reason}) async =>
      teamMemberFromApi(_obj(await _client.patch('/admin/team/$adminId/active',
          body: {'active': active, if (reason != null) 'reason': reason})));

  Future<void> revokeAccess(String adminId) =>
      _client.delete('/admin/team/$adminId');

  // ═══════════════════════════════════════════════════════════════════════════
  // Settings and the record
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> settings() async =>
      _obj(await _client.get('/admin/settings'));

  /// Saves the rate card and limits.
  ///
  /// [expectedVersion] is what makes this safe: the server refuses the save if
  /// somebody else changed the settings in the meantime, rather than letting
  /// one admin silently overwrite another's rate change.
  Future<Map<String, dynamic>> saveSettings({
    required int expectedVersion,
    required Map<String, dynamic> settings,
  }) async =>
      _obj(await _client.put('/admin/settings',
          body: {'expectedVersion': expectedVersion, 'settings': settings}));

  Future<Page<AuditEntry>> audit({int page = 0, int size = 100}) async =>
      Page.fromApi(
        await _client.get('/admin/audit', query: {'page': page, 'size': size}),
        auditRowFromApi,
      );

  // ── Plumbing ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _obj(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const [];
}
