/// What the panel knows about lending beyond the loans themselves: who looks
/// after each borrower, the groups they borrow in, the loans written on paper
/// and the file that goes with each, and every repayment that came in.
library;

import '../../core/constants/app_config.dart';
import '_wire.dart';
import 'admin.dart';
import 'loan_application.dart';
import 'platform_settings.dart';

// ── Loan officers ─────────────────────────────────────────────────────────

/// Somebody on the team who can be made a loan officer.
class OfficerOption {
  const OfficerOption({
    required this.id,
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.borrowers,
  });

  final String id;
  final String name;
  final String email;
  final String roleLabel;

  /// How many borrowers they already look after.
  final int borrowers;

  static OfficerOption fromApi(Map<String, dynamic> j) => OfficerOption(
    id: str(j['id']),
    name: str(j['name']),
    email: str(j['email']),
    roleLabel: str(j['roleLabel']),
    borrowers: integer(j['borrowers']),
  );
}

/// An officer on a borrower, as the panel sees it.
class AssignedOfficer {
  const AssignedOfficer({
    required this.id,
    required this.officerId,
    required this.name,
    required this.email,
    required this.lead,
    required this.stillOnTeam,
    required this.assignedAt,
    this.phone = '',
    this.assignedBy = '',
  });

  /// The assignment, not the person — what "make lead" and "remove" act on.
  final String id;
  final String officerId;
  final String name;
  final String email;
  final String phone;
  final bool lead;

  /// False once their panel access was taken away. The borrower still needs
  /// somebody who is.
  final bool stillOnTeam;
  final DateTime assignedAt;
  final String assignedBy;

  static AssignedOfficer fromApi(Map<String, dynamic> j) => AssignedOfficer(
    id: str(j['id']),
    officerId: str(j['officerId']),
    name: str(j['name']),
    email: str(j['email']),
    phone: str(j['phone']),
    lead: boolean(j['lead']),
    stillOnTeam: boolean(j['stillOnTeam'], true),
    assignedAt: date(j['assignedAt']),
    assignedBy: str(j['assignedBy']),
  );
}

/// An officer as the customer sees them: the name only, never their email or
/// phone.
class MyOfficer {
  const MyOfficer({required this.name, this.lead = false});

  final String name;
  final bool lead;

  static MyOfficer fromApi(Map<String, dynamic> j) =>
      MyOfficer(name: str(j['name']), lead: boolean(j['lead']));
}

/// One borrower in an officer's book.
class OfficerBorrower {
  const OfficerBorrower({
    required this.assignmentId,
    required this.name,
    required this.signedUp,
    required this.lead,
    required this.assignedAt,
    this.customerId = '',
    this.importedLoanId = '',
    this.customerRef = '',
  });

  final String assignmentId;
  final String customerId;
  final String importedLoanId;
  final String name;
  final String customerRef;
  final bool signedUp;
  final bool lead;
  final DateTime assignedAt;

  static OfficerBorrower fromApi(Map<String, dynamic> j) => OfficerBorrower(
    assignmentId: str(j['assignmentId']),
    customerId: str(j['customerId']),
    importedLoanId: str(j['importedLoanId']),
    name: str(j['name']),
    customerRef: str(j['customerRef']),
    signedUp: boolean(j['signedUp']),
    lead: boolean(j['lead']),
    assignedAt: date(j['assignedAt']),
  );
}

// ── Loan groups ───────────────────────────────────────────────────────────

/// A numbered, named group of borrowers, run by one loan officer. Members
/// borrow on the loan-group terms.
class LoanGroup {
  const LoanGroup({
    required this.id,
    required this.number,
    required this.name,
    required this.officerId,
    required this.officerName,
    required this.active,
    required this.members,
    required this.signedUp,
    required this.totalLent,
    required this.outstanding,
    required this.overdueMembers,
    required this.createdAt,
    this.area = '',
    this.description = '',
    this.officerEmail = '',
    this.officerStillOnTeam = true,
    this.createdBy = '',
    this.canManage = false,
  });

  final String id;
  final int number;
  final String name;
  final String area;
  final String description;
  final String officerId;
  final String officerName;
  final String officerEmail;
  final bool officerStillOnTeam;
  final bool active;
  final int members;

  /// How many members have opened their own account.
  final int signedUp;
  final double totalLent;
  final double outstanding;
  final int overdueMembers;
  final DateTime createdAt;
  final String createdBy;

  /// Whether the signed-in admin may add, edit and remove members — the
  /// group's officer, an owner or an administrator.
  final bool canManage;

  /// "Group 4 · Oja Oba".
  String get title => 'Group $number · $name';

  static LoanGroup fromApi(Map<String, dynamic> j) => LoanGroup(
    id: str(j['id']),
    number: integer(j['number']),
    name: str(j['name']),
    area: str(j['area']),
    description: str(j['description']),
    officerId: str(j['officerId']),
    officerName: str(j['officerName']),
    officerEmail: str(j['officerEmail']),
    officerStillOnTeam: boolean(j['officerStillOnTeam'], true),
    active: boolean(j['active'], true),
    members: integer(j['members']),
    signedUp: integer(j['signedUp']),
    totalLent: money(j['totalLent']),
    outstanding: money(j['outstanding']),
    overdueMembers: integer(j['overdueMembers']),
    createdAt: date(j['createdAt']),
    createdBy: str(j['createdBy']),
    canManage: boolean(j['canManage']),
  );
}

class LoanGroupMember {
  const LoanGroupMember({
    required this.id,
    required this.name,
    required this.signedUp,
    required this.loans,
    required this.lent,
    required this.outstanding,
    required this.overdue,
    required this.addedAt,
    this.customerId = '',
    this.importedLoanId = '',
    this.customerRef = '',
    this.phone = '',
    this.nextDue,
    this.addedBy = '',
  });

  final String id;
  final String customerId;
  final String importedLoanId;
  final String name;
  final String customerRef;
  final String phone;
  final bool signedUp;
  final int loans;
  final double lent;
  final double outstanding;
  final bool overdue;
  final DateTime? nextDue;
  final DateTime addedAt;
  final String addedBy;

  static LoanGroupMember fromApi(Map<String, dynamic> j) => LoanGroupMember(
    id: str(j['id']),
    customerId: str(j['customerId']),
    importedLoanId: str(j['importedLoanId']),
    name: str(j['name']),
    customerRef: str(j['customerRef']),
    phone: str(j['phone']),
    signedUp: boolean(j['signedUp']),
    loans: integer(j['loans']),
    lent: money(j['lent']),
    outstanding: money(j['outstanding']),
    overdue: boolean(j['overdue']),
    nextDue: dateOrNull(j['nextDue']),
    addedAt: date(j['addedAt']),
    addedBy: str(j['addedBy']),
  );
}

class LoanGroupDetail {
  const LoanGroupDetail({required this.group, required this.members});

  final LoanGroup group;
  final List<LoanGroupMember> members;

  static LoanGroupDetail fromApi(Map<String, dynamic> j) => LoanGroupDetail(
    group: LoanGroup.fromApi(obj(j['group'])),
    members: list(j['members']).map(LoanGroupMember.fromApi).toList(),
  );
}

/// Who is in which group, for labelling the customer list.
class GroupLabel {
  const GroupLabel({
    required this.groupId,
    required this.number,
    required this.name,
    this.customerId = '',
    this.importedLoanId = '',
  });

  final String customerId;
  final String importedLoanId;
  final String groupId;
  final int number;
  final String name;

  static GroupLabel fromApi(Map<String, dynamic> j) => GroupLabel(
    customerId: str(j['customerId']),
    importedLoanId: str(j['importedLoanId']),
    groupId: str(j['groupId']),
    number: integer(j['number']),
    name: str(j['name']),
  );
}

// ── Loans written outside the app ─────────────────────────────────────────

/// How money came back outside the app.
enum RepaymentMethod { cash, bankTransfer, pos, cheque, other }

extension RepaymentMethodX on RepaymentMethod {
  String get wire => toWire(this);

  String get label => switch (this) {
    RepaymentMethod.cash => 'Cash',
    RepaymentMethod.bankTransfer => 'Bank transfer',
    RepaymentMethod.pos => 'POS',
    RepaymentMethod.cheque => 'Cheque',
    RepaymentMethod.other => 'Other',
  };
}

/// A loan entered by hand, with the borrower's file.
///
/// Until its borrower signs up it sits on an account the team opened for them
/// — waiting for activation — and the moment they sign up with the BVN on it,
/// the loan is on their own account with every repayment already counted.
class ImportedLoan {
  const ImportedLoan({
    required this.id,
    required this.fullName,
    required this.principal,
    required this.tenureMonths,
    required this.frequency,
    required this.flatRate,
    required this.processingFee,
    required this.purpose,
    required this.totalRepayable,
    required this.amountRepaid,
    required this.outstanding,
    required this.claimed,
    this.bvnLast4 = '',
    this.email = '',
    this.phone = '',
    this.transactionFee = 0,
    this.repaymentFeeRate = 0,
    this.repaymentFees = 0,
    this.installmentCount = 0,
    this.wholeNaira = true,
    this.netDisbursed = 0,
    this.disbursedAt,
    this.dueDate,
    this.importedBy = '',
    this.importedAt,
    this.claimedAt,
    this.customerId = '',
    this.loanId = '',
    this.ninLast4 = '',
    this.dateOfBirth,
    this.gender = '',
    this.address = '',
    this.state = '',
    this.occupation = '',
    this.businessName = '',
    this.businessAddress = '',
    this.monthlyIncome = 0,
    this.payoutBank = '',
    this.payoutAccountNumber = '',
    this.notes = '',
    this.guarantors = const [],
  });

  final String id;
  final String bvnLast4;
  final String fullName;
  final String email;
  final String phone;
  final double principal;
  final int tenureMonths;
  final RepaymentFrequency frequency;
  final double flatRate;

  /// The management fee taken when the loan was given.
  final double processingFee;

  /// A flat transaction fee taken when the loan was given — older loans only.
  final double transactionFee;

  /// The transaction fee on each repayment, and what those fees add up to.
  final double repaymentFeeRate;
  final double repaymentFees;
  final int installmentCount;
  final bool wholeNaira;

  /// What the borrower actually received.
  final double netDisbursed;
  final String purpose;
  final DateTime? disbursedAt;
  final DateTime? dueDate;
  final double totalRepayable;
  final double amountRepaid;
  final double outstanding;
  final String importedBy;
  final DateTime? importedAt;

  /// Whether its borrower has signed up and taken the loan onto their account.
  final bool claimed;
  final DateTime? claimedAt;
  final String customerId;
  final String loanId;
  final String ninLast4;
  final DateTime? dateOfBirth;
  final String gender;
  final String address;
  final String state;
  final String occupation;
  final String businessName;
  final String businessAddress;
  final double monthlyIncome;
  final String payoutBank;
  final String payoutAccountNumber;
  final String notes;
  final List<Guarantor> guarantors;

  bool get isOpen => outstanding > 0.01;

  /// "6 months, repaid monthly".
  String get termPhrase =>
      '${frequency.length(tenureMonths, count: installmentCount == 0 ? null : installmentCount)}, '
      'repaid ${frequency.adjective}';

  static ImportedLoan fromApi(Map<String, dynamic> j) => ImportedLoan(
    id: str(j['id']),
    bvnLast4: str(j['bvnLast4']),
    fullName: str(j['fullName']),
    email: str(j['email']),
    phone: str(j['phone']),
    principal: money(j['principal']),
    tenureMonths: integer(j['tenureMonths'], 1),
    frequency: RepaymentFrequency.fromWire(j['repaymentFrequency']),
    flatRate: money(j['flatRate']),
    processingFee: money(j['processingFee']),
    transactionFee: money(j['transactionFee']),
    repaymentFeeRate: money(j['repaymentFeeRate']),
    repaymentFees: money(j['repaymentFees']),
    installmentCount: integer(j['installmentCount']),
    wholeNaira: boolean(j['wholeNaira'], true),
    netDisbursed: money(j['netDisbursed']),
    purpose: str(j['purpose']),
    disbursedAt: dateOrNull(j['disbursedAt']),
    dueDate: dateOrNull(j['dueDate']),
    totalRepayable: money(j['totalRepayable']),
    amountRepaid: money(j['amountRepaid']),
    outstanding: money(j['outstanding']),
    importedBy: str(j['importedBy']),
    importedAt: dateOrNull(j['importedAt']),
    claimed: boolean(j['claimed']),
    claimedAt: dateOrNull(j['claimedAt']),
    customerId: str(j['customerId']),
    loanId: str(j['loanId']),
    ninLast4: str(j['ninLast4']),
    dateOfBirth: dateOrNull(j['dateOfBirth']),
    gender: str(j['gender']),
    address: str(j['address']),
    state: str(j['state']),
    occupation: str(j['occupation']),
    businessName: str(j['businessName']),
    businessAddress: str(j['businessAddress']),
    monthlyIncome: money(j['monthlyIncome']),
    payoutBank: str(j['payoutBank']),
    payoutAccountNumber: str(j['payoutAccountNumber']),
    notes: str(j['notes']),
    guarantors: list(j['guarantors']).map(Guarantor.fromJson).toList(),
  );

  /// The thin row the panel's lists draw from.
  WaitingLoan get asWaiting => WaitingLoan(
    id: id,
    fullName: fullName,
    email: email,
    phone: phone,
    principal: principal,
    outstanding: outstanding,
    tenureMonths: tenureMonths,
    purpose: purpose,
    disbursedAt: disbursedAt,
    dueDate: dueDate,
  );
}

/// One document attached to a loan's file, behind a signed link that expires.
class OfflineDocument {
  const OfflineDocument({
    required this.id,
    required this.label,
    required this.url,
    required this.uploadedAt,
    this.contentType = '',
    this.sizeBytes = 0,
    this.filename = '',
    this.uploadedBy = '',
  });

  final String id;
  final String label;
  final String contentType;
  final int sizeBytes;
  final String filename;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String url;

  bool get isImage => contentType.toLowerCase().startsWith('image/');

  static OfflineDocument fromApi(Map<String, dynamic> j) => OfflineDocument(
    id: str(j['id']),
    label: str(j['label']),
    contentType: str(j['contentType']),
    sizeBytes: integer(j['sizeBytes']),
    filename: str(j['filename']),
    uploadedBy: str(j['uploadedBy']),
    uploadedAt: date(j['uploadedAt']),
    url: AppConfig.absoluteUrl(str(j['url'])),
  );
}

/// A repayment that came in outside the app — cash, or a transfer straight to
/// the company account — recorded by somebody on the team. It never touched a
/// wallet.
class OfflineRepayment {
  const OfflineRepayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.method,
    required this.recordedAt,
    this.importedLoanId = '',
    this.loanId = '',
    this.reference = '',
    this.note = '',
    this.recordedBy = '',
  });

  final String id;
  final String importedLoanId;
  final String loanId;
  final double amount;
  final DateTime paidAt;
  final RepaymentMethod method;
  final String reference;
  final String note;
  final String recordedBy;
  final DateTime recordedAt;

  static OfflineRepayment fromApi(Map<String, dynamic> j) => OfflineRepayment(
    id: str(j['id']),
    importedLoanId: str(j['importedLoanId']),
    loanId: str(j['loanId']),
    amount: money(j['amount']),
    paidAt: date(j['paidAt']),
    method: wireEnum(j['method'], RepaymentMethod.values, RepaymentMethod.other),
    reference: str(j['reference']),
    note: str(j['note']),
    recordedBy: str(j['recordedBy']),
    recordedAt: date(j['recordedAt']),
  );
}

/// One paper loan with its whole file.
class OfflineLoanFile {
  const OfflineLoanFile({
    required this.loan,
    required this.documents,
    required this.repayments,
  });

  final ImportedLoan loan;
  final List<OfflineDocument> documents;
  final List<OfflineRepayment> repayments;

  static OfflineLoanFile fromApi(Map<String, dynamic> j) => OfflineLoanFile(
    loan: ImportedLoan.fromApi(obj(j['loan'])),
    documents: list(j['documents']).map(OfflineDocument.fromApi).toList(),
    repayments: list(j['repayments']).map(OfflineRepayment.fromApi).toList(),
  );
}

/// What sits on a loan beyond its figures: documents and repayments recorded
/// by hand. On a customer, across every loan they have had.
class LoanRecords {
  const LoanRecords({
    this.documents = const [],
    this.repayments = const [],
    this.importedLoans = const [],
  });

  final List<OfflineDocument> documents;
  final List<OfflineRepayment> repayments;
  final List<ImportedLoan> importedLoans;

  bool get isEmpty => documents.isEmpty && repayments.isEmpty && importedLoans.isEmpty;

  static LoanRecords fromApi(Map<String, dynamic> j) => LoanRecords(
    documents: list(j['documents']).map(OfflineDocument.fromApi).toList(),
    repayments: list(j['repayments']).map(OfflineRepayment.fromApi).toList(),
    importedLoans: list(j['importedLoans']).map(ImportedLoan.fromApi).toList(),
  );
}

/// Who a BVN already belongs to, so another loan goes on their account
/// rather than a second account being opened for the same person.
class BvnMatch {
  const BvnMatch({
    required this.found,
    this.customerId = '',
    this.fullName = '',
    this.customerRef = '',
    this.accountStatusLabel = '',
    this.hasRunningLoan = false,
  });

  final bool found;
  final String customerId;
  final String fullName;
  final String customerRef;
  final String accountStatusLabel;
  final bool hasRunningLoan;

  static BvnMatch fromApi(Map<String, dynamic> j) => BvnMatch(
    found: boolean(j['found']),
    customerId: str(j['customerId']),
    fullName: str(j['fullName']),
    customerRef: str(j['customerRef']),
    accountStatusLabel: str(j['accountStatusLabel']),
    hasRunningLoan: boolean(j['hasRunningLoan']),
  );
}

/// A repayment taken by hand, as it is sent.
class RepaymentEntry {
  const RepaymentEntry({
    required this.amount,
    required this.method,
    this.paidAt,
    this.reference = '',
    this.note = '',
  });

  final double amount;
  final RepaymentMethod method;
  final DateTime? paidAt;
  final String reference;
  final String note;

  Map<String, dynamic> toApi() => {
    'amount': amount,
    'method': method.wire,
    if (paidAt != null) 'paidAt': paidAt!.toUtc().toIso8601String(),
    if (reference.trim().isNotEmpty) 'reference': reference.trim(),
    if (note.trim().isNotEmpty) 'note': note.trim(),
  };
}

// ── Repayment history ─────────────────────────────────────────────────────

/// How a repayment reached the loan.
enum RepaymentSource { paystack, wallet, bankTransfer, recorded }

extension RepaymentSourceX on RepaymentSource {
  String get wire => toWire(this);

  String get label => switch (this) {
    RepaymentSource.paystack => 'Paystack',
    RepaymentSource.wallet => 'Wallet',
    RepaymentSource.bankTransfer => 'Bank transfer',
    RepaymentSource.recorded => 'Recorded by hand',
  };
}

class RepaymentRow {
  const RepaymentRow({
    required this.id,
    required this.paidAt,
    required this.amount,
    required this.source,
    required this.sourceLabel,
    required this.customerName,
    this.customerId = '',
    this.customerRef = '',
    this.loanId = '',
    this.importedLoanId = '',
    this.loanPurpose = '',
    this.reference = '',
    this.description = '',
    this.recordedBy = '',
  });

  final String id;
  final DateTime paidAt;
  final double amount;
  final RepaymentSource source;
  final String sourceLabel;

  /// Empty for a loan entered by hand whose borrower has not signed up.
  final String customerId;
  final String customerName;
  final String customerRef;
  final String loanId;
  final String importedLoanId;
  final String loanPurpose;
  final String reference;
  final String description;
  final String recordedBy;

  static RepaymentRow fromApi(Map<String, dynamic> j) => RepaymentRow(
    id: str(j['id']),
    paidAt: date(j['paidAt']),
    amount: money(j['amount']),
    source: wireEnum(j['source'], RepaymentSource.values, RepaymentSource.wallet),
    sourceLabel: str(j['sourceLabel']),
    customerId: str(j['customerId']),
    customerName: str(j['customerName']),
    customerRef: str(j['customerRef']),
    loanId: str(j['loanId']),
    importedLoanId: str(j['importedLoanId']),
    loanPurpose: str(j['loanPurpose']),
    reference: str(j['reference']),
    description: str(j['description']),
    recordedBy: str(j['recordedBy']),
  );
}

/// Totals for everything the filters match, not only the page shown.
class RepaymentSummary {
  const RepaymentSummary({
    this.total = 0,
    this.count = 0,
    this.today = 0,
    this.todayCount = 0,
    this.thisMonth = 0,
    this.thisMonthCount = 0,
    this.viaPaystack = 0,
    this.fromWallet = 0,
    this.bankTransfer = 0,
    this.recordedByHand = 0,
  });

  final double total;
  final int count;
  final double today;
  final int todayCount;
  final double thisMonth;
  final int thisMonthCount;
  final double viaPaystack;
  final double fromWallet;
  final double bankTransfer;
  final double recordedByHand;

  static RepaymentSummary fromApi(Map<String, dynamic> j) => RepaymentSummary(
    total: money(j['total']),
    count: integer(j['count']),
    today: money(j['today']),
    todayCount: integer(j['todayCount']),
    thisMonth: money(j['thisMonth']),
    thisMonthCount: integer(j['thisMonthCount']),
    viaPaystack: money(j['viaPaystack']),
    fromWallet: money(j['fromWallet']),
    bankTransfer: money(j['bankTransfer']),
    recordedByHand: money(j['recordedByHand']),
  );
}

class RepaymentHistory {
  const RepaymentHistory({
    required this.rows,
    required this.summary,
    this.hasMore = false,
  });

  final List<RepaymentRow> rows;
  final RepaymentSummary summary;
  final bool hasMore;

  static RepaymentHistory fromApi(Map<String, dynamic> j) {
    final page = obj(j['page']);
    final rows = list(page['items'] ?? page['content']).map(RepaymentRow.fromApi).toList();
    return RepaymentHistory(
      rows: rows,
      summary: RepaymentSummary.fromApi(obj(j['summary'])),
      hasMore: boolean(page['hasNext']) ||
          integer(page['page']) + 1 < integer(page['totalPages'], 1),
    );
  }
}

// ── Signed agreements ─────────────────────────────────────────────────────

/// A signature given when the agreements were accepted.
///
/// The customer's own view carries the image itself, so they have their copy;
/// the panel's carries a signed link through the endpoint that audits each
/// view.
class SignatureRecord {
  const SignatureRecord({
    required this.id,
    required this.typedName,
    required this.documents,
    required this.signedAt,
    this.device = '',
    this.image = '',
    this.url = '',
  });

  final String id;
  final String typedName;

  /// "lending 1.1, privacy 1.2, terms 1.2".
  final String documents;
  final DateTime signedAt;
  final String device;

  /// A PNG data URL, on the customer's own view.
  final String image;

  /// A signed, expiring link, on the panel's.
  final String url;

  static SignatureRecord fromApi(Map<String, dynamic> j) => SignatureRecord(
    id: str(j['id']),
    typedName: str(j['typedName']),
    documents: str(j['documents']),
    signedAt: date(j['signedAt']),
    device: str(j['device']),
    image: str(j['image']),
    url: AppConfig.absoluteUrl(str(j['url'])),
  );
}

// ── Reports ───────────────────────────────────────────────────────────────

/// The reports the panel can download.
enum ExportReportName {
  customers,
  loans,
  repayments,
  transactions,
  paystack,
  withdrawals,
  applications,
}

extension ExportReportNameX on ExportReportName {
  String get label => switch (this) {
    ExportReportName.customers => 'Customers',
    ExportReportName.loans => 'Loans',
    ExportReportName.repayments => 'Repayments',
    ExportReportName.transactions => 'Transactions',
    ExportReportName.paystack => 'Paystack payments',
    ExportReportName.withdrawals => 'Withdrawals',
    ExportReportName.applications => 'Loan applications',
  };

  String get blurb => switch (this) {
    ExportReportName.customers => 'Every account, its status and balances',
    ExportReportName.loans => 'The lending book, running and closed',
    ExportReportName.repayments => 'Every repayment, however it came in',
    ExportReportName.transactions => 'The ledger: every wallet movement',
    ExportReportName.paystack => 'Card, transfer and USSD payments',
    ExportReportName.withdrawals => 'Payouts requested and sent',
    ExportReportName.applications => 'Applications to borrow and their outcome',
  };
}

enum ExportColumnType { text, money, number, date }

class ExportColumn {
  const ExportColumn(this.label, this.type);
  final String label;
  final ExportColumnType type;
}

/// A report: columns, then rows of cells in the same order.
class ExportReport {
  const ExportReport({
    required this.title,
    required this.period,
    required this.generatedAt,
    required this.generatedBy,
    required this.company,
    required this.columns,
    required this.rows,
  });

  final String title;
  final String period;
  final DateTime generatedAt;
  final String generatedBy;
  final String company;
  final List<ExportColumn> columns;
  final List<List<Object?>> rows;

  static ExportReport fromApi(Map<String, dynamic> j) => ExportReport(
    title: str(j['title']),
    period: str(j['period']),
    generatedAt: date(j['generatedAt']),
    generatedBy: str(j['generatedBy']),
    company: str(j['company']),
    columns: list(j['columns'])
        .map((c) => ExportColumn(
              str(c['label']),
              wireEnum(c['type'], ExportColumnType.values, ExportColumnType.text),
            ))
        .toList(),
    rows: (j['rows'] as List? ?? const [])
        .whereType<List>()
        .map((r) => List<Object?>.from(r))
        .toList(),
  );
}
