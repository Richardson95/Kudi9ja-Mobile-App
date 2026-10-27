import '../../core/constants/app_config.dart';
import '../models/admin.dart';
import '../models/deposit.dart';
import '../models/lending_admin.dart';
import '../models/loan_application.dart';
import '../models/models.dart';
import '../models/paystack.dart';
import '../models/support.dart';
import '../models/withdrawal.dart';
import 'api_client.dart';
import 'api_exception.dart';
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

  /// The book-wide totals, counted by the server across every customer.
  Future<PlatformBook> book() async => platformBookFromApi(await overview());

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

  /// Freezes, unfreezes or otherwise moves an account. The reason is
  /// required: it is the record of why, and the server refuses a change
  /// without one.
  Future<void> setCustomerStatus(String id,
          {required String status, required String reason}) =>
      _client.post('/admin/customers/$id/status',
          body: {'status': status, 'reason': reason});

  Future<void> flagCustomer(String id, {required String reason}) =>
      _client.post('/admin/customers/$id/flag', body: {'reason': reason});

  /// The signatures the customer gave when accepting their agreements, each
  /// behind a signed link whose every view is audited.
  Future<List<SignatureRecord>> customerSignatures(String id) async =>
      _list(await _client.get('/admin/customers/$id/signatures'))
          .map(SignatureRecord.fromApi)
          .toList();

  /// Everything recorded by hand about a customer: loans entered from paper,
  /// documents on any of their loans, repayments taken outside the app.
  Future<LoanRecords> customerLoanRecords(String id) async =>
      LoanRecords.fromApi(_obj(await _client.get('/admin/customers/$id/loan-records')));

  /// Payments a customer made through Paystack.
  Future<Page<PaystackPayment>> customerPaystack(String id) async => Page.fromApi(
        await _client.get('/admin/payins/paystack',
            query: {'customerId': id, 'size': 50}),
        PaystackPayment.fromApi,
      );

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
    final url = body['url'] as String? ?? body['receiptUrl'] as String?;
    return url == null ? null : AppConfig.absoluteUrl(url);
  }

  // -- Borrowing ------------------------------------------------------------

  /// The application queue. `status` null means every application ever made.
  Future<Page<LoanApplication>> loanApplications({
    LoanApplicationStatus? status,
    int page = 0,
    int size = 50,
  }) async =>
      Page.fromApi(
        await _client.get('/admin/loan-applications', query: {
          if (status != null) 'status': status.name.toUpperCase(),
          'page': page,
          'size': size,
        }),
        loanApplicationFromApi,
      );

  /// One application in full, with signed links to every document on it.
  ///
  /// The links expire, and opening one is written to the audit log — a bank
  /// statement says more about somebody than anything else they send us.
  Future<LoanApplication> loanApplication(String id) async =>
      loanApplicationFromApi(
          _obj(await _client.get('/admin/loan-applications/$id')));

  /// Approves and disburses. The money reaches the wallet on this call.
  Future<LoanApplication> approveLoanApplication(String id, {String? note}) async =>
      loanApplicationFromApi(_obj(await _client.post(
        '/admin/loan-applications/$id/approve',
        body: {if (note != null && note.isNotEmpty) 'note': note},
      )));

  /// Declines, with a reason the customer is shown word for word.
  Future<LoanApplication> rejectLoanApplication(String id, String reason) async =>
      loanApplicationFromApi(_obj(await _client.post(
        '/admin/loan-applications/$id/reject',
        body: {'reason': reason},
      )));

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

  /// Every payment taken through Paystack, newest first. Read-only: Paystack
  /// decides whether a payment happened.
  Future<Page<PaystackPayment>> paystackPayments({
    String? status,
    int page = 0,
    int size = 50,
  }) async =>
      Page.fromApi(
        await _client.get('/admin/payins/paystack',
            query: {'status': status, 'page': page, 'size': size}),
        PaystackPayment.fromApi,
      );

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

  /// The lending book. Without a status this is every loan, closed included.
  Future<Page<BookLoan>> loans({
    int page = 0,
    int size = 50,
    String? status,
  }) async =>
      Page.fromApi(
        await _client.get('/admin/loans',
            query: {'page': page, 'size': size, 'status': status}),
        bookLoanFromApi,
      );

  /// Paper loans entered against a BVN whose borrower has not signed up yet.
  Future<List<WaitingLoan>> waitingLoans() async =>
      _list(await _client.get('/admin/loans/imports', query: {'claimed': false}))
          .map(waitingLoanFromApi)
          .toList();

  // -- Loans written outside the app ---------------------------------------

  /// Every loan entered by hand. `claimed` false: still waiting for their
  /// borrower to sign up; true: on an account; null: both.
  Future<List<ImportedLoan>> importedLoans({bool? claimed}) async =>
      _list(await _client.get('/admin/loans/imports',
              query: {if (claimed != null) 'claimed': claimed}))
          .map(ImportedLoan.fromApi)
          .toList();

  /// Enters a loan written outside the app, with the borrower's file.
  ///
  /// Opens an account for the borrower on the spot — waiting for them to
  /// activate it by signing up with the BVN — or, with `customerId`, puts the
  /// loan on an account that already exists.
  Future<ImportedLoan> importLoan(Map<String, dynamic> input) async =>
      ImportedLoan.fromApi(_obj(await _client.post('/admin/loans/imports',
          idempotencyKey: Kudi9jaApi.newKey(), body: input)));

  /// Whether a BVN already belongs to a customer, so another loan goes on
  /// their account instead of a second account being opened.
  Future<BvnMatch> lookupBvn(String bvn) async => BvnMatch.fromApi(
      _obj(await _client.get('/admin/loans/imports/lookup', query: {'bvn': bvn})));

  Future<OfflineLoanFile> importedLoan(String id) async =>
      OfflineLoanFile.fromApi(_obj(await _client.get('/admin/loans/imports/$id')));

  /// Corrects the borrower's file. Identity fields only while the loan is
  /// still waiting; the money terms are corrected by entering it again.
  Future<OfflineLoanFile> updateImportedLoan(
          String id, Map<String, dynamic> changes) async =>
      OfflineLoanFile.fromApi(_obj(
          await _client.patch('/admin/loans/imports/$id', body: changes)));

  Future<OfflineDocument> attachToImport(
    String id, {
    required List<int> bytes,
    required String filename,
    String? contentType,
    required String label,
  }) async =>
      OfflineDocument.fromApi(_obj(await _client.upload(
        '/admin/loans/imports/$id/documents',
        fieldName: 'file',
        bytes: bytes,
        filename: filename,
        contentType: contentType,
        fields: {'label': label},
      )));

  Future<void> removeDocument(String documentId) =>
      _client.delete('/admin/loans/imports/documents/$documentId');

  /// Records a repayment that came in outside the app on a paper loan. Never
  /// touches a wallet.
  Future<void> recordOnImport(String id, RepaymentEntry entry) =>
      _client.post('/admin/loans/imports/$id/repayments',
          idempotencyKey: Kudi9jaApi.newKey(), body: entry.toApi());

  /// The same, on a loan already on an account. The borrower is notified.
  Future<void> recordOnLoan(String loanId, RepaymentEntry entry) =>
      _client.post('/admin/loans/$loanId/repayments',
          idempotencyKey: Kudi9jaApi.newKey(), body: entry.toApi());

  /// Takes back a repayment recorded by mistake. A loan it had closed is
  /// running again.
  Future<void> removeRecordedRepayment(String repaymentId) =>
      _client.delete('/admin/loans/imports/repayments/$repaymentId');

  /// Documents and hand-recorded repayments on a loan.
  Future<LoanRecords> loanRecords(String loanId) async =>
      LoanRecords.fromApi(_obj(await _client.get('/admin/loans/$loanId/records')));

  Future<OfflineDocument> attachToLoan(
    String loanId, {
    required List<int> bytes,
    required String filename,
    String? contentType,
    required String label,
  }) async =>
      OfflineDocument.fromApi(_obj(await _client.upload(
        '/admin/loans/$loanId/documents',
        fieldName: 'file',
        bytes: bytes,
        filename: filename,
        contentType: contentType,
        fields: {'label': label},
      )));

  /// Removes an entry nobody has claimed yet.
  Future<void> deleteImportedLoan(String id) =>
      _client.delete('/admin/loans/imports/$id');

  // -- Repayments ----------------------------------------------------------

  /// Every repayment customers have made, newest first, with totals for
  /// everything the filters match.
  Future<RepaymentHistory> repayments({
    String? query,
    RepaymentSource? source,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async =>
      RepaymentHistory.fromApi(_obj(await _client.get('/admin/repayments', query: {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (source != null) 'source': source.wire,
        if (from != null) 'from': _isoDate(from),
        if (to != null) 'to': _isoDate(to),
        'page': page,
        'size': size,
      })));

  // ═══════════════════════════════════════════════════════════════════════════
  // Loan officers and groups
  // ═══════════════════════════════════════════════════════════════════════════

  /// Everyone who can be made a loan officer, with how many borrowers each has.
  Future<List<OfficerOption>> officerOptions() async =>
      _list(await _client.get('/admin/officers')).map(OfficerOption.fromApi).toList();

  Future<List<OfficerBorrower>> officerBook(String officerId) async =>
      _list(await _client.get('/admin/officers/$officerId/borrowers'))
          .map(OfficerBorrower.fromApi)
          .toList();

  Future<List<AssignedOfficer>> customerOfficers(String customerId) async =>
      _list(await _client.get('/admin/customers/$customerId/officers'))
          .map(AssignedOfficer.fromApi)
          .toList();

  Future<List<AssignedOfficer>> assignToCustomer(
    String customerId,
    List<String> officerIds, {
    bool lead = false,
  }) async =>
      _list(await _client.post('/admin/customers/$customerId/officers',
              body: {'officerIds': officerIds, 'lead': lead}))
          .map(AssignedOfficer.fromApi)
          .toList();

  Future<List<AssignedOfficer>> importOfficers(String importId) async =>
      _list(await _client.get('/admin/loans/imports/$importId/officers'))
          .map(AssignedOfficer.fromApi)
          .toList();

  Future<List<AssignedOfficer>> assignToImport(
    String importId,
    List<String> officerIds, {
    bool lead = false,
  }) async =>
      _list(await _client.post('/admin/loans/imports/$importId/officers',
              body: {'officerIds': officerIds, 'lead': lead}))
          .map(AssignedOfficer.fromApi)
          .toList();

  Future<void> makeLeadOfficer(String assignmentId) =>
      _client.post('/admin/officers/assignments/$assignmentId/lead');

  /// Takes an officer off a borrower. Refused for the last one: every
  /// borrower has somebody.
  Future<void> removeOfficer(String assignmentId) =>
      _client.delete('/admin/officers/assignments/$assignmentId');

  Future<List<LoanGroup>> groups() async =>
      _list(await _client.get('/admin/groups')).map(LoanGroup.fromApi).toList();

  Future<int> nextGroupNumber() async =>
      (_obj(await _client.get('/admin/groups/next-number'))['number'] as num?)
          ?.toInt() ??
      1;

  Future<List<GroupLabel>> groupLabels() async =>
      _list(await _client.get('/admin/groups/labels')).map(GroupLabel.fromApi).toList();

  Future<LoanGroupDetail> createGroup({
    int? number,
    required String name,
    String area = '',
    String description = '',
    required String officerId,
  }) async =>
      LoanGroupDetail.fromApi(_obj(await _client.post('/admin/groups', body: {
        if (number != null) 'number': number,
        'name': name,
        if (area.trim().isNotEmpty) 'area': area.trim(),
        if (description.trim().isNotEmpty) 'description': description.trim(),
        'officerId': officerId,
      })));

  Future<LoanGroupDetail> group(String id) async =>
      LoanGroupDetail.fromApi(_obj(await _client.get('/admin/groups/$id')));

  /// Renames, describes, closes, or hands a group to another officer. Only
  /// what is sent changes.
  Future<LoanGroupDetail> updateGroup(
    String id, {
    String? name,
    String? area,
    String? description,
    String? officerId,
    bool? active,
  }) async =>
      LoanGroupDetail.fromApi(_obj(await _client.patch('/admin/groups/$id', body: {
        if (name != null) 'name': name,
        if (area != null) 'area': area,
        if (description != null) 'description': description,
        if (officerId != null) 'officerId': officerId,
        if (active != null) 'active': active,
      })));

  /// Adds a customer who already has an account, by their customer reference.
  Future<LoanGroupDetail> addToGroup(String id, String customerRef) async =>
      LoanGroupDetail.fromApi(_obj(await _client
          .post('/admin/groups/$id/customers', body: {'customerRef': customerRef})));

  /// Takes a borrower out of a group. Their loan is unchanged.
  Future<LoanGroupDetail> removeFromGroup(String id, String memberId) async =>
      LoanGroupDetail.fromApi(
          _obj(await _client.delete('/admin/groups/$id/members/$memberId')));

  Future<List<LoanGroup>> customerGroups(String customerId) async =>
      _list(await _client.get('/admin/customers/$customerId/groups'))
          .map(LoanGroup.fromApi)
          .toList();

  // ═══════════════════════════════════════════════════════════════════════════
  // Help and complaints
  // ═══════════════════════════════════════════════════════════════════════════

  Future<SupportQueueSummary> supportSummary() async =>
      SupportQueueSummary.fromApi(_obj(await _client.get('/admin/support/summary')));

  /// The queue: waiting on the team first, then latest.
  Future<Page<SupportConversation>> supportQueue({
    SupportStatus? status,
    String? customerId,
    String? query,
    int page = 0,
    int size = 100,
  }) async =>
      Page.fromApi(
        await _client.get('/admin/support/conversations', query: {
          if (status != null) 'status': status.wire,
          if (customerId != null) 'customerId': customerId,
          if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
          'page': page,
          'size': size,
        }),
        SupportConversation.fromApi,
      );

  /// A conversation and its messages. Marks the team's side read.
  Future<SupportThread> supportThread(String id) async =>
      SupportThread.fromApi(_obj(await _client.get('/admin/support/conversations/$id')));

  /// Replies. The customer is notified.
  Future<SupportMessage> supportReply(String id, String body) async =>
      SupportMessage.fromApi(_obj(await _client
          .post('/admin/support/conversations/$id/messages', body: {'body': body})));

  Future<SupportMessage> supportAttach(
    String id, {
    required List<int> bytes,
    required String filename,
    String? contentType,
    String? body,
  }) async =>
      SupportMessage.fromApi(_obj(await _client.upload(
        '/admin/support/conversations/$id/attachments',
        fieldName: 'file',
        bytes: bytes,
        filename: filename,
        contentType: contentType,
        fields: {if (body != null && body.trim().isNotEmpty) 'body': body.trim()},
      )));

  /// Takes it on.
  Future<SupportConversation> supportAssign(String id) async =>
      SupportConversation.fromApi(
          _obj(await _client.post('/admin/support/conversations/$id/assign')));

  /// Marks it resolved, with a note the customer sees.
  Future<SupportConversation> supportResolve(String id, {String? note}) async =>
      SupportConversation.fromApi(_obj(await _client.post(
          '/admin/support/conversations/$id/resolve',
          body: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()})));

  Future<SupportConversation> supportReopen(String id) async =>
      SupportConversation.fromApi(
          _obj(await _client.post('/admin/support/conversations/$id/reopen')));

  Future<void> supportTyping(String id) async {
    try {
      await _client.post('/admin/support/conversations/$id/typing');
    } on ApiException {
      // Stored nowhere; a hint that did not arrive changes nothing.
    }
  }

  /// The live stream for the whole queue.
  Stream<SupportEvent> supportEvents() => _client
      .events('/admin/support/stream')
      .map(supportEventFrom)
      .where((e) => e != null)
      .cast();

  // ═══════════════════════════════════════════════════════════════════════════
  // Reports and announcements
  // ═══════════════════════════════════════════════════════════════════════════

  /// One report's rows. Owners and administrators only; every download is
  /// logged.
  Future<ExportReport> exportReport(
    ExportReportName name, {
    DateTime? from,
    DateTime? to,
  }) async =>
      ExportReport.fromApi(_obj(await _client.get('/admin/exports/${name.name}', query: {
        if (from != null) 'from': _isoDate(from),
        if (to != null) 'to': _isoDate(to),
      })));

  /// A push notification to every registered phone. Cannot be taken back.
  /// Returns how many phones it is on its way to.
  Future<int> announce({
    required String title,
    required String body,
    String? imageUrl,
  }) async =>
      (_obj(await _client.post('/admin/announcements', body: {
        'title': title,
        'body': body,
        if (imageUrl != null && imageUrl.trim().isNotEmpty) 'imageUrl': imageUrl.trim(),
      }))['devices'] as num?)
          ?.toInt() ??
      0;

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

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _obj(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const [];
}
